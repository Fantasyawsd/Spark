import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/chat_context.dart';
import '../domain/chat_message.dart';
import '../domain/chat_session_repository.dart';
import 'chat_ai_service.dart';

enum ChatRequestStatus { idle, sending, completed, cancelled, failed }

class ChatConversationController extends ChangeNotifier {
  ChatConversationController({
    required this.context,
    required ChatAiService service,
    ChatAiService? webSearchService,
    ChatSessionRepository? sessionRepository,
  })  : _service = service,
        _webSearchService = webSearchService,
        _sessionRepository = sessionRepository;

  final ChatContext context;
  final ChatAiService _service;
  final ChatAiService? _webSearchService;
  final ChatSessionRepository? _sessionRepository;
  final List<ChatMessage> _messages = [];

  bool _sending = false;
  bool _loading = false;
  bool _disposed = false;
  bool _webSearchEnabled = false;
  bool _searching = false;
  ChatReasoningEffort _reasoningEffort = ChatReasoningEffort.high;
  ChatRequestStatus _requestStatus = ChatRequestStatus.idle;
  String? _requestError;
  String? _persistenceError;
  int _requestVersion = 0;
  int _writeVersion = 0;
  int? _activeAssistantIndex;
  ChatAiService? _activeService;
  Future<void> _writeQueue = Future.value();
  Timer? _streamNotifyTimer;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;
  bool get loading => _loading;
  String? get error => _requestError ?? _persistenceError;
  bool get canRetry =>
      !_sending &&
      _messages.isNotEmpty &&
      (_requestStatus == ChatRequestStatus.cancelled ||
          _requestStatus == ChatRequestStatus.failed);

  bool get canRetryRequestError => canRetry && _requestError != null;

  bool get _canRegenerateLatest {
    if (_sending || _messages.isEmpty) return false;

    final last = _messages.last;
    return canRetry ||
        (!last.fromUser && last.status == ChatMessageStatus.complete);
  }

  bool get webSearchAvailable => _webSearchService != null;
  bool get webSearchEnabled => _webSearchEnabled;
  bool get searching => _searching;
  ChatReasoningEffort get reasoningEffort => _reasoningEffort;
  ChatRequestStatus get requestStatus => _requestStatus;

  void setWebSearchEnabled(bool enabled) {
    if (_sending || !webSearchAvailable || enabled == _webSearchEnabled) return;
    _webSearchEnabled = enabled;
    _notify();
  }

  void setReasoningEffort(ChatReasoningEffort effort) {
    if (_sending || effort == _reasoningEffort) return;
    _reasoningEffort = effort;
    _notify();
  }

  Future<void> initialize() async {
    final repository = _sessionRepository;
    if (repository == null || _loading || _messages.isNotEmpty) return;
    _loading = true;
    _notify();
    try {
      final stored = await repository.load(context.id);
      if (_disposed) return;
      _messages
        ..clear()
        ..addAll(stored);
      if (stored.isEmpty) {
        _requestStatus = ChatRequestStatus.idle;
      } else if (stored.last.status == ChatMessageStatus.cancelled) {
        _requestStatus = ChatRequestStatus.cancelled;
      } else if (stored.last.status == ChatMessageStatus.failed ||
          stored.last.fromUser) {
        _requestStatus = ChatRequestStatus.failed;
        _requestError = '上次回答未完成，请重新生成。';
      } else {
        _requestStatus = ChatRequestStatus.completed;
      }
    } on ChatSessionPersistenceException catch (error) {
      if (!_disposed) _persistenceError = error.message;
    } finally {
      if (!_disposed) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;
    _removeTrailingEmptyTerminalMessage();
    _messages.add(ChatMessage(fromUser: true, content: text));
    await _requestAnswer();
  }

  Future<void> retry() async {
    if (!_canRegenerateLatest) return;

    // 重新生成只替换最后一条 Assistant 回复，保留对应的用户 Prompt。
    // 失败/停止时如果服务还没有来得及创建 Assistant 占位消息，最后一条
    // 就会是用户消息，此时直接沿用它，不能再次追加同一条 Prompt。
    if (_messages.last case final last when !last.fromUser) {
      _messages.removeLast();
    }
    await _requestAnswer();
  }

  Future<void> editLatestPromptAndRetry(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;

    final promptIndex = _messages.lastIndexWhere((message) => message.fromUser);
    if (promptIndex < 0) return;

    _messages[promptIndex] = _messages[promptIndex].copyWith(content: text);
    if (promptIndex + 1 < _messages.length) {
      _messages.removeRange(promptIndex + 1, _messages.length);
    }
    await _requestAnswer();
  }

  void deleteMessageAt(int index) {
    deleteMessagesAt([index]);
  }

  void deleteMessagesAt(Iterable<int> indexes) {
    if (_sending) return;
    final selected = indexes
        .where((index) => index >= 0 && index < _messages.length)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (selected.isEmpty) return;

    for (final index in selected) {
      _messages.removeAt(index);
    }
    _requestError = null;
    _requestStatus = _messages.isEmpty
        ? ChatRequestStatus.idle
        : ChatRequestStatus.completed;
    _persist();
    _notify();
  }

  void cancel() {
    if (!_sending) return;
    _requestVersion++;
    if (_activeService case final CancellableChatAiService cancellable) {
      cancellable.cancelActiveRequest();
    }
    _markActiveAssistant(ChatMessageStatus.cancelled);
    _activeAssistantIndex = null;
    _activeService = null;
    _searching = false;
    _streamNotifyTimer?.cancel();
    _sending = false;
    _requestError = null;
    _requestStatus = ChatRequestStatus.cancelled;
    _persist();
    _notify();
  }

  Future<void> clear() async {
    cancel();
    _messages.clear();
    _requestError = null;
    _persistenceError = null;
    _requestStatus = ChatRequestStatus.idle;
    _notify();
    final repository = _sessionRepository;
    if (repository == null) return;
    final writeVersion = ++_writeVersion;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.clear(context.id);
      } on ChatSessionPersistenceException catch (error) {
        if (!_disposed && writeVersion == _writeVersion) {
          _persistenceError = error.message;
          _notify();
        }
      }
    });
    await _writeQueue;
  }

  Future<void> _requestAnswer() async {
    final requestVersion = ++_requestVersion;
    _sending = true;
    _requestStatus = ChatRequestStatus.sending;
    _requestError = null;
    _searching = false;
    _persist();
    _notify();
    try {
      final service = _webSearchEnabled && _webSearchService != null
          ? _webSearchService!
          : _service;
      if (service case final ConfigurableChatAiService configurable) {
        configurable.setReasoningEffort(_reasoningEffort);
      }
      _activeService = service;
      if (service case final StreamingChatAiService streamingService) {
        await _consumeStream(streamingService, requestVersion);
      } else {
        final answer = await service.answer(
          context: context,
          conversation: List.unmodifiable(_messages),
        );
        if (_disposed || requestVersion != _requestVersion) return;
        _messages.add(ChatMessage(fromUser: false, content: answer));
      }
      if (_disposed || requestVersion != _requestVersion) return;
      _activeAssistantIndex = null;
      _activeService = null;
      _searching = false;
      _streamNotifyTimer?.cancel();
      _sending = false;
      _requestStatus = ChatRequestStatus.completed;
      _persist();
      _notify();
    } on ChatAiCancelledException {
      if (_disposed || requestVersion != _requestVersion) return;
      _markActiveAssistant(ChatMessageStatus.cancelled);
      _activeAssistantIndex = null;
      _activeService = null;
      _searching = false;
      _streamNotifyTimer?.cancel();
      _sending = false;
      _requestError = null;
      _requestStatus = ChatRequestStatus.cancelled;
      _persist();
      _notify();
    } on ChatAiException catch (error) {
      _setError(requestVersion, error.message);
    } on Exception {
      _setError(requestVersion, 'AI 服务发生未知错误，请稍后重试。');
    }
  }

  void _setError(int requestVersion, String message) {
    if (_disposed || requestVersion != _requestVersion) return;
    _markActiveAssistant(ChatMessageStatus.failed);
    _activeAssistantIndex = null;
    _activeService = null;
    _searching = false;
    _streamNotifyTimer?.cancel();
    _sending = false;
    _requestError = message;
    _requestStatus = ChatRequestStatus.failed;
    _persist();
    _notify();
  }

  Future<void> _consumeStream(
    StreamingChatAiService service,
    int requestVersion,
  ) async {
    final conversation = List<ChatMessage>.unmodifiable(_messages);
    await for (final chunk in service.answerStream(
      context: context,
      conversation: conversation,
    )) {
      if (_disposed || requestVersion != _requestVersion) return;
      var assistantIndex = _activeAssistantIndex;
      if (assistantIndex == null) {
        assistantIndex = _messages.length;
        _activeAssistantIndex = assistantIndex;
        _messages.add(
          const ChatMessage(fromUser: false, content: ''),
        );
      }
      final current = _messages[assistantIndex];
      final sourcesByUrl = <String, ChatSource>{
        for (final source in current.sources) source.url: source,
        for (final source in chunk.sources) source.url: source,
      };
      _messages[assistantIndex] = current.copyWith(
        content: current.content + chunk.contentDelta,
        reasoningContent: current.reasoningContent + chunk.reasoningDelta,
        sources: sourcesByUrl.values.toList(growable: false),
      );
      if (chunk.searchStarted) _searching = true;
      if (chunk.searchFinished) _searching = false;
      if (chunk.contentDelta.isNotEmpty) _searching = false;
      _scheduleStreamNotify();
    }
    final assistantIndex = _activeAssistantIndex;
    if (assistantIndex == null ||
        _messages[assistantIndex].content.trim().isEmpty) {
      throw const ChatAiException('AI 返回了空响应，请稍后重试。');
    }
  }

  void _persist() {
    final repository = _sessionRepository;
    if (repository == null) return;
    final writeVersion = ++_writeVersion;
    _persistenceError = null;
    final snapshot = List<ChatMessage>.from(_messages);
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(context.id, snapshot);
      } on ChatSessionPersistenceException catch (error) {
        if (!_disposed && writeVersion == _writeVersion) {
          _persistenceError = error.message;
          _notify();
        }
      }
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _scheduleStreamNotify() {
    if (_streamNotifyTimer?.isActive ?? false) return;
    _streamNotifyTimer = Timer(const Duration(milliseconds: 32), _notify);
  }

  void _markActiveAssistant(ChatMessageStatus status) {
    final assistantIndex = _activeAssistantIndex;
    if (assistantIndex == null || assistantIndex >= _messages.length) {
      _messages.add(
        ChatMessage(fromUser: false, content: '', status: status),
      );
      return;
    }
    final assistant = _messages[assistantIndex];
    _messages[assistantIndex] = assistant.copyWith(
      status: status,
    );
  }

  void _removeTrailingEmptyTerminalMessage() {
    if (_messages.isEmpty) return;
    final last = _messages.last;
    if (last.fromUser ||
        last.status == ChatMessageStatus.complete ||
        last.content.trim().isNotEmpty ||
        last.reasoningContent.trim().isNotEmpty ||
        last.sources.isNotEmpty) {
      return;
    }
    _messages.removeLast();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _streamNotifyTimer?.cancel();
    if (_activeService case final CancellableChatAiService cancellable) {
      cancellable.cancelActiveRequest();
    }
    super.dispose();
  }
}
