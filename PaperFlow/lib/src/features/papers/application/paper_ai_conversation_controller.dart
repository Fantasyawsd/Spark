import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/paper.dart';
import 'paper_ai_service.dart';
import 'paper_ai_session_repository.dart';

class PaperAiConversationController extends ChangeNotifier {
  PaperAiConversationController({
    required this.paper,
    required PaperAiService service,
    PaperAiService? webSearchService,
    PaperAiSessionRepository? sessionRepository,
  })  : _service = service,
        _webSearchService = webSearchService,
        _sessionRepository = sessionRepository;

  final PaperRecord paper;
  final PaperAiService _service;
  final PaperAiService? _webSearchService;
  final PaperAiSessionRepository? _sessionRepository;
  final List<PaperAiMessage> _messages = [];

  bool _sending = false;
  bool _loading = false;
  bool _disposed = false;
  bool _webSearchEnabled = false;
  bool _searching = false;
  PaperAiReasoningEffort _reasoningEffort = PaperAiReasoningEffort.medium;
  String? _error;
  int _requestVersion = 0;
  int? _activeAssistantIndex;
  int? _failedAssistantIndex;
  PaperAiService? _activeService;
  Future<void> _writeQueue = Future.value();
  Timer? _streamNotifyTimer;

  List<PaperAiMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;
  bool get loading => _loading;
  String? get error => _error;
  bool get canRetry => !_sending && _error != null && _messages.isNotEmpty;
  bool get webSearchAvailable => _webSearchService != null;
  bool get webSearchEnabled => _webSearchEnabled;
  bool get searching => _searching;
  PaperAiReasoningEffort get reasoningEffort => _reasoningEffort;

  void setWebSearchEnabled(bool enabled) {
    if (_sending || !webSearchAvailable || enabled == _webSearchEnabled) return;
    _webSearchEnabled = enabled;
    _notify();
  }

  void setReasoningEffort(PaperAiReasoningEffort effort) {
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
      final stored = await repository.load(paper.id);
      if (_disposed) return;
      _messages
        ..clear()
        ..addAll(stored);
    } on PaperAiSessionPersistenceException catch (error) {
      if (!_disposed) _error = error.message;
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
    _messages.add(PaperAiMessage(fromUser: true, content: text));
    await _requestAnswer();
  }

  Future<void> retry() async {
    if (!canRetry) return;
    final failedIndex = _failedAssistantIndex;
    if (failedIndex != null && failedIndex < _messages.length) {
      _messages.removeAt(failedIndex);
    }
    _failedAssistantIndex = null;
    await _requestAnswer();
  }

  void cancel() {
    if (!_sending) return;
    _requestVersion++;
    if (_activeService case final CancellablePaperAiService cancellable) {
      cancellable.cancelActiveRequest();
    }
    final assistantIndex = _activeAssistantIndex;
    if (assistantIndex != null &&
        assistantIndex < _messages.length &&
        _messages[assistantIndex].content.trim().isEmpty) {
      _messages.removeAt(assistantIndex);
    }
    _activeAssistantIndex = null;
    _activeService = null;
    _searching = false;
    _streamNotifyTimer?.cancel();
    _sending = false;
    _error = null;
    _persist();
    _notify();
  }

  Future<void> clear() async {
    cancel();
    _messages.clear();
    _error = null;
    _notify();
    final repository = _sessionRepository;
    if (repository == null) return;
    try {
      await repository.clear(paper.id);
    } on PaperAiSessionPersistenceException catch (error) {
      if (!_disposed) {
        _error = error.message;
        _notify();
      }
    }
  }

  Future<void> _requestAnswer() async {
    final requestVersion = ++_requestVersion;
    _sending = true;
    _error = null;
    _failedAssistantIndex = null;
    _searching = false;
    _notify();
    _persist();
    try {
      final service = _webSearchEnabled && _webSearchService != null
          ? _webSearchService!
          : _service;
      if (service case final ConfigurablePaperAiService configurable) {
        configurable.setReasoningEffort(_reasoningEffort);
      }
      _activeService = service;
      if (service case final StreamingPaperAiService streamingService) {
        await _consumeStream(streamingService, requestVersion);
      } else {
        final answer = await service.answer(
          paper: paper,
          conversation: List.unmodifiable(_messages),
        );
        if (_disposed || requestVersion != _requestVersion) return;
        _messages.add(PaperAiMessage(fromUser: false, content: answer));
      }
      if (_disposed || requestVersion != _requestVersion) return;
      _activeAssistantIndex = null;
      _activeService = null;
      _searching = false;
      _streamNotifyTimer?.cancel();
      _sending = false;
      _persist();
      _notify();
    } on PaperAiCancelledException {
      if (_disposed || requestVersion != _requestVersion) return;
      _sending = false;
      _notify();
    } on PaperAiException catch (error) {
      _setError(requestVersion, error.message);
    } on Exception {
      _setError(requestVersion, 'AI 服务发生未知错误，请稍后重试。');
    }
  }

  void _setError(int requestVersion, String message) {
    if (_disposed || requestVersion != _requestVersion) return;
    _failedAssistantIndex = _activeAssistantIndex;
    _activeAssistantIndex = null;
    _activeService = null;
    _searching = false;
    _streamNotifyTimer?.cancel();
    _sending = false;
    _error = message;
    _persist();
    _notify();
  }

  Future<void> _consumeStream(
    StreamingPaperAiService service,
    int requestVersion,
  ) async {
    final conversation = List<PaperAiMessage>.unmodifiable(_messages);
    await for (final chunk in service.answerStream(
      paper: paper,
      conversation: conversation,
    )) {
      if (_disposed || requestVersion != _requestVersion) return;
      var assistantIndex = _activeAssistantIndex;
      if (assistantIndex == null) {
        assistantIndex = _messages.length;
        _activeAssistantIndex = assistantIndex;
        _messages.add(
          const PaperAiMessage(fromUser: false, content: ''),
        );
      }
      final current = _messages[assistantIndex];
      final sourcesByUrl = <String, PaperAiSource>{
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
      throw const PaperAiException('DeepSeek 返回了空响应，请稍后重试。');
    }
  }

  void _persist() {
    final repository = _sessionRepository;
    if (repository == null) return;
    final snapshot = List<PaperAiMessage>.from(_messages);
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(paper.id, snapshot);
      } on PaperAiSessionPersistenceException catch (error) {
        if (!_disposed) {
          _error = error.message;
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

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _streamNotifyTimer?.cancel();
    if (_activeService case final CancellablePaperAiService cancellable) {
      cancellable.cancelActiveRequest();
    }
    super.dispose();
  }
}
