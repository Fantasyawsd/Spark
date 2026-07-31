import 'package:flutter/foundation.dart';

import '../domain/chat_session_repository.dart';

class ChatContextSummary {
  const ChatContextSummary({required this.id, required this.title});

  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatContextSummary && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

class ChatSessionEntry {
  const ChatSessionEntry({required this.session, required this.context});

  final ChatSessionSummary session;
  final ChatContextSummary context;
}

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({
    required ChatSessionRepository repository,
    required String mainSessionId,
    Iterable<ChatContextSummary> contexts = const [],
  })  : _repository = repository,
        _mainSessionId = mainSessionId,
        _contexts = {for (final context in contexts) context.id: context};

  final ChatSessionRepository _repository;
  final String _mainSessionId;
  Map<String, ChatContextSummary> _contexts;
  List<ChatSessionEntry> _entries = const [];
  ChatSessionSummary? _mainSession;
  bool _loading = false;
  bool _disposed = false;
  String? _error;
  Future<void>? _activeLoad;

  List<ChatSessionEntry> get entries => _entries;
  ChatSessionSummary? get mainSession => _mainSession;
  bool get loading => _loading;
  String? get error => _error;

  void updateContexts(Iterable<ChatContextSummary> contexts) {
    final next = {for (final context in contexts) context.id: context};
    if (mapEquals(_contexts, next)) return;
    _contexts = next;
    _rebuildEntries(_rawSessions);
    _notify();
  }

  List<ChatSessionSummary> _rawSessions = const [];

  Future<void> refresh() {
    final active = _activeLoad;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _load().whenComplete(() {
      if (identical(_activeLoad, operation)) _activeLoad = null;
    });
    _activeLoad = operation;
    return operation;
  }

  Future<void> togglePinned(String contextId) async {
    final session =
        _rawSessions.where((item) => item.contextId == contextId).firstOrNull;
    if (session == null) return;
    try {
      await _repository.setPinned(contextId, !session.pinned);
      await _reloadAfterMutation();
    } on ChatSessionPersistenceException catch (error) {
      _setError(error.message);
    }
  }

  Future<void> delete(String contextId) async {
    try {
      await _repository.clear(contextId);
      _rawSessions = _rawSessions
          .where((session) => session.contextId != contextId)
          .toList(growable: false);
      _rebuildEntries(_rawSessions);
      _error = null;
      _notify();
    } on ChatSessionPersistenceException catch (error) {
      _setError(error.message);
    }
  }

  Future<void> _load() async {
    _loading = true;
    _notify();
    try {
      final sessions = await _repository.listSessions();
      if (_disposed) return;
      _rawSessions = sessions;
      _rebuildEntries(sessions);
      _error = null;
    } on ChatSessionPersistenceException catch (error) {
      if (!_disposed) _error = error.message;
    } finally {
      if (!_disposed) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> _reloadAfterMutation() async {
    final sessions = await _repository.listSessions();
    if (_disposed) return;
    _rawSessions = sessions;
    _rebuildEntries(sessions);
    _error = null;
    _notify();
  }

  void _rebuildEntries(List<ChatSessionSummary> sessions) {
    _mainSession = sessions
        .where((session) => session.contextId == _mainSessionId)
        .firstOrNull;
    final entries = <ChatSessionEntry>[];
    for (final session in sessions) {
      if (session.contextId == _mainSessionId) continue;
      final context = _contexts[session.contextId];
      if (context != null) {
        entries.add(ChatSessionEntry(session: session, context: context));
      }
    }
    entries.sort((left, right) {
      if (left.session.pinned != right.session.pinned) {
        return left.session.pinned ? -1 : 1;
      }
      return right.session.updatedAt.compareTo(left.session.updatedAt);
    });
    _entries = List.unmodifiable(entries);
  }

  void _setError(String message) {
    _error = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
