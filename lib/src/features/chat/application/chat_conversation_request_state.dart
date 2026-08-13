import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/chat_ai_service.dart';
import '../domain/chat_context.dart';
import '../domain/chat_message.dart';

enum ChatRequestStatus { idle, sending, completed, cancelled, failed }

class ChatConversationRequestState {
  ChatConversationRequestState({
    required ChatAiService service,
    required ChatAiService? webSearchService,
    required List<ChatMessage> messages,
    required ChatContext Function() effectiveContext,
    required bool Function() isDisposed,
    required VoidCallback persist,
    required VoidCallback notify,
  })  : _service = service,
        _webSearchService = webSearchService,
        _messages = messages,
        _effectiveContext = effectiveContext,
        _isDisposed = isDisposed,
        _persist = persist,
        _notify = notify;

  final ChatAiService _service;
  final ChatAiService? _webSearchService;
  final List<ChatMessage> _messages;
  final ChatContext Function() _effectiveContext;
  final bool Function() _isDisposed;
  final VoidCallback _persist;
  final VoidCallback _notify;

  bool _sending = false;
  bool _webSearchEnabled = false;
  bool _searching = false;
  ChatReasoningEffort _reasoningEffort = ChatReasoningEffort.high;
  ChatRequestStatus _status = ChatRequestStatus.idle;
  String? _error;
  int _version = 0;
  int? _activeAssistantIndex;
  ChatAiService? _activeService;
  ChatRequestCancellation? _activeCancellation;
  Timer? _streamNotifyTimer;

  bool get sending => _sending;
  bool get webSearchAvailable => _webSearchService != null;
  bool get webSearchEnabled => _webSearchEnabled;
  bool get searching => _searching;
  ChatReasoningEffort get reasoningEffort => _reasoningEffort;
  ChatRequestStatus get status => _status;
  String? get error => _error;

  bool get canRetry =>
      !_sending &&
      _messages.isNotEmpty &&
      (_status == ChatRequestStatus.cancelled ||
          _status == ChatRequestStatus.failed);

  bool get canRetryRequestError => canRetry && _error != null;

  bool get canRegenerateLatest {
    if (_sending || _messages.isEmpty) return false;
    final last = _messages.last;
    return canRetry ||
        (!last.fromUser && last.status == ChatMessageStatus.complete);
  }

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

  void restoreFromMessages() {
    _error = null;
    if (_messages.isEmpty) {
      _status = ChatRequestStatus.idle;
    } else if (_messages.last.status == ChatMessageStatus.cancelled) {
      _status = ChatRequestStatus.cancelled;
    } else if (_messages.last.status == ChatMessageStatus.failed ||
        _messages.last.fromUser) {
      _status = ChatRequestStatus.failed;
      _error = '上次回答未完成，请重新生成。';
    } else {
      _status = ChatRequestStatus.completed;
    }
  }

  void resetAfterMessageChange() {
    _error = null;
    _status = _messages.isEmpty
        ? ChatRequestStatus.idle
        : ChatRequestStatus.completed;
  }

  void reset() {
    _error = null;
    _status = ChatRequestStatus.idle;
  }

  void prepareForSend() {
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

  Future<void> requestAnswer() async {
    final requestVersion = ++_version;
    _sending = true;
    _status = ChatRequestStatus.sending;
    _error = null;
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
      if (service
          case final RequestScopedStreamingChatAiService scopedService) {
        final cancellation = ChatRequestCancellation();
        _activeCancellation = cancellation;
        await _consumeStream(
          scopedService.answerStream(
            context: _effectiveContext(),
            conversation: _conversationForRequest(),
            cancellation: cancellation,
          ),
          requestVersion,
        );
      } else if (service case final StreamingChatAiService streamingService) {
        await _consumeStream(
          streamingService.answerStream(
            context: _effectiveContext(),
            conversation: _conversationForRequest(),
          ),
          requestVersion,
        );
      } else {
        final answer = await service.answer(
          context: _effectiveContext(),
          conversation: _conversationForRequest(),
        );
        if (_isDisposed() || requestVersion != _version) return;
        _messages.add(ChatMessage(fromUser: false, content: answer));
      }
      if (_isDisposed() || requestVersion != _version) return;
      _complete(ChatRequestStatus.completed);
    } on ChatAiCancelledException {
      if (_isDisposed() || requestVersion != _version) return;
      _markActiveAssistant(ChatMessageStatus.cancelled);
      _complete(ChatRequestStatus.cancelled);
    } on ChatAiException catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.chatConversationRequest,
        error: error,
        stackTrace: stackTrace,
      );
      _setError(requestVersion, error.message);
    } on Exception catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.chatConversationRequest,
        error: error,
        stackTrace: stackTrace,
      );
      _setError(requestVersion, 'AI 服务发生未知错误，请稍后重试。');
    }
  }

  void cancel() {
    if (!_sending) return;
    _version++;
    _cancelActiveService();
    _markActiveAssistant(ChatMessageStatus.cancelled);
    _complete(ChatRequestStatus.cancelled);
  }

  void dispose() {
    _version++;
    _streamNotifyTimer?.cancel();
    _cancelActiveService();
  }

  Future<void> _consumeStream(
    Stream<ChatStreamChunk> stream,
    int requestVersion,
  ) async {
    await for (final chunk in stream) {
      if (_isDisposed() || requestVersion != _version) return;
      var assistantIndex = _activeAssistantIndex;
      if (assistantIndex == null) {
        assistantIndex = _messages.length;
        _activeAssistantIndex = assistantIndex;
        _messages.add(const ChatMessage(fromUser: false, content: ''));
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

  void _setError(int requestVersion, String message) {
    if (_isDisposed() || requestVersion != _version) return;
    _markActiveAssistant(ChatMessageStatus.failed);
    _complete(ChatRequestStatus.failed, error: message);
  }

  void _complete(ChatRequestStatus status, {String? error}) {
    _activeAssistantIndex = null;
    _activeService = null;
    _activeCancellation = null;
    _searching = false;
    _streamNotifyTimer?.cancel();
    _sending = false;
    _error = error;
    _status = status;
    _persist();
    _notify();
  }

  void _cancelActiveService() {
    final cancellation = _activeCancellation;
    cancellation?.cancel();
    if (cancellation == null) {
      final activeService = _activeService;
      if (activeService is CancellableChatAiService) {
        activeService.cancelActiveRequest();
      }
    }
    _activeService = null;
    _activeCancellation = null;
  }

  void _scheduleStreamNotify() {
    if (_streamNotifyTimer?.isActive ?? false) return;
    _streamNotifyTimer = Timer(const Duration(milliseconds: 32), _notify);
  }

  void _markActiveAssistant(ChatMessageStatus status) {
    final assistantIndex = _activeAssistantIndex;
    if (assistantIndex == null || assistantIndex >= _messages.length) {
      _messages.add(ChatMessage(fromUser: false, content: '', status: status));
      return;
    }
    final assistant = _messages[assistantIndex];
    _messages[assistantIndex] = assistant.copyWith(status: status);
  }

  List<ChatMessage> _conversationForRequest() => List.unmodifiable(
        _messages.where(
          (message) =>
              message.fromUser || message.status == ChatMessageStatus.complete,
        ),
      );
}
