import 'package:flutter/foundation.dart';

export 'chat_conversation_request_state.dart' show ChatRequestStatus;

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/chat_context.dart';
import '../domain/chat_ai_service.dart';
import '../domain/chat_message.dart';
import '../domain/chat_session_repository.dart';
import '../domain/chat_session_settings.dart';
import 'chat_conversation_request_state.dart';
import 'chat_conversation_settings_state.dart';
import 'chat_prompt_assembler.dart';
import 'chat_conversation_write_queue.dart';

class ChatConversationController extends ChangeNotifier {
  ChatConversationController({
    required this.context,
    required ChatAiService service,
    ChatAiService? webSearchService,
    ChatSessionRepository? sessionRepository,
    ChatSessionSettingsRepository? settingsRepository,
  }) : _sessionRepository = sessionRepository {
    _settingsState = ChatConversationSettingsState(
      contextId: context.id,
      repository: settingsRepository,
      isDisposed: () => _disposed,
      notify: _notify,
    );
    _requestState = ChatConversationRequestState(
      service: service,
      webSearchService: webSearchService,
      messages: _messages,
      effectiveContext: () => effectiveContext,
      isDisposed: () => _disposed,
      persist: _persist,
      notify: _notify,
    );
  }
  ChatContext context;
  final ChatSessionRepository? _sessionRepository;
  final List<ChatMessage> _messages = [];
  late final ChatConversationSettingsState _settingsState;
  late final ChatConversationRequestState _requestState;

  bool _loading = false;
  bool _disposed = false;
  String? _persistenceError;
  int _writeVersion = 0;
  Future<void>? _initialization;
  late final ChatConversationWriteQueue _writeQueue =
      ChatConversationWriteQueue(
    onQueueError: reportChatConversationWriteQueueError,
  );

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _requestState.sending;
  bool get loading => _loading;
  ChatSessionSettings get settings => _settingsState.value;
  ChatContext get effectiveContext =>
      ChatPromptAssembler.applySettings(context, _settingsState.value);
  String? get error =>
      _requestState.error ??
      _persistenceError ??
      _settingsState.persistenceError;
  bool get canRetry => _requestState.canRetry;
  bool get canRetryRequestError => _requestState.canRetryRequestError;

  bool get webSearchAvailable => _requestState.webSearchAvailable;
  bool get webSearchEnabled => _requestState.webSearchEnabled;
  bool get searching => _requestState.searching;
  ChatReasoningEffort get reasoningEffort => _requestState.reasoningEffort;

  /// 在保持会话身份不变的前提下替换上下文（例如注入论文 PDF 全文）。
  /// 返回 false 表示 id 不匹配，替换被拒绝。
  bool replaceContext(ChatContext nextContext) {
    if (nextContext.id != context.id) return false;
    context = nextContext;
    _notify();
    return true;
  }

  ChatRequestStatus get requestStatus => _requestState.status;

  void setWebSearchEnabled(bool enabled) =>
      _requestState.setWebSearchEnabled(enabled);

  void setReasoningEffort(ChatReasoningEffort effort) =>
      _requestState.setReasoningEffort(effort);

  Future<void> updateSettings(ChatSessionSettings settings) async {
    await _settingsState.update(settings);
  }

  Future<void> initialize() {
    if (_disposed) return Future.value();
    final existing = _initialization;
    if (existing != null) return existing;
    if (_messages.isNotEmpty) return Future.value();
    late final Future<void> operation;
    operation = _initialize().whenComplete(() {
      if (identical(_initialization, operation)) _initialization = null;
    });
    _initialization = operation;
    return operation;
  }

  Future<void> _initialize() async {
    _loading = true;
    _notify();
    try {
      final repository = _sessionRepository;
      if (repository != null) {
        final stored = await repository.load(context.id);
        if (_disposed) return;
        _messages
          ..clear()
          ..addAll(stored);
        _requestState.restoreFromMessages();
      }

      await _settingsState.load();
    } on ChatSessionPersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.chatConversationSessionLoad,
        error,
        stackTrace,
      );
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
    if (text.isEmpty) return;
    final initialization = _initialization;
    if (initialization != null) await initialization;
    if (_disposed || sending) return;
    _requestState.prepareForSend();
    _messages.add(ChatMessage(fromUser: true, content: text));
    await _requestState.requestAnswer();
  }

  Future<void> retry() async {
    if (!_requestState.canRegenerateLatest) return;

    // 重新生成只替换最后一条 Assistant 回复，保留对应的用户 Prompt。
    // 失败/停止时如果服务还没有来得及创建 Assistant 占位消息，最后一条
    // 就会是用户消息，此时直接沿用它，不能再次追加同一条 Prompt。
    if (_messages.last case final last when !last.fromUser) {
      _messages.removeLast();
    }
    await _requestState.requestAnswer();
  }

  Future<void> editLatestPromptAndRetry(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || sending) return;

    final promptIndex = _messages.lastIndexWhere((message) => message.fromUser);
    if (promptIndex < 0) return;

    _messages[promptIndex] = _messages[promptIndex].copyWith(content: text);
    if (promptIndex + 1 < _messages.length) {
      _messages.removeRange(promptIndex + 1, _messages.length);
    }
    await _requestState.requestAnswer();
  }

  void deleteMessageAt(int index) {
    deleteMessagesAt([index]);
  }

  void deleteMessagesAt(Iterable<int> indexes) {
    if (sending) return;
    final selected = indexes
        .where((index) => index >= 0 && index < _messages.length)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (selected.isEmpty) return;

    for (final index in selected) {
      _messages.removeAt(index);
    }
    _requestState.resetAfterMessageChange();
    _persist();
    _notify();
  }

  void cancel() => _requestState.cancel();

  Future<void> clear() async {
    cancel();
    _messages.clear();
    _persistenceError = null;
    _requestState.reset();
    _notify();
    final repository = _sessionRepository;
    if (repository == null) return;
    final writeVersion = ++_writeVersion;
    final operation = _writeQueue.enqueue(() async {
      try {
        await repository.clear(context.id);
      } on ChatSessionPersistenceException catch (error, stackTrace) {
        _reportPersistenceFailure(
          SparkDiagnosticOperation.chatConversationClear,
          error,
          stackTrace,
        );
        if (!_disposed && writeVersion == _writeVersion) {
          _persistenceError = error.message;
          _notify();
        }
      } on Object catch (error, stackTrace) {
        _reportPersistenceFailure(
          SparkDiagnosticOperation.chatConversationClear,
          error,
          stackTrace,
        );
        if (!_disposed && writeVersion == _writeVersion) {
          _persistenceError = '无法清空 AI 对话记录。';
          _notify();
        }
      }
    });
    await operation;
  }

  void _persist() {
    final repository = _sessionRepository;
    if (repository == null) return;
    final writeVersion = ++_writeVersion;
    _persistenceError = null;
    final snapshot = List<ChatMessage>.from(_messages);
    _writeQueue.enqueue(() async {
      try {
        await repository.save(context.id, snapshot);
      } on ChatSessionPersistenceException catch (error, stackTrace) {
        _reportPersistenceFailure(
          SparkDiagnosticOperation.chatConversationSave,
          error,
          stackTrace,
        );
        if (!_disposed && writeVersion == _writeVersion) {
          _persistenceError = error.message;
          _notify();
        }
      } on Object catch (error, stackTrace) {
        _reportPersistenceFailure(
          SparkDiagnosticOperation.chatConversationSave,
          error,
          stackTrace,
        );
        if (!_disposed && writeVersion == _writeVersion) {
          _persistenceError = '无法保存 AI 对话记录。';
          _notify();
        }
      }
    });
  }

  static void _reportPersistenceFailure(
    SparkDiagnosticOperation operation,
    Object error,
    StackTrace stackTrace,
  ) {
    SparkDiagnostics.reportUnexpected(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      severity: SparkDiagnosticSeverity.warning,
    );
  }

  Future<void> flushPendingWrites() => _writeQueue.flush();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestState.dispose();
    super.dispose();
  }
}
