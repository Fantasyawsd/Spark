import 'dart:async';

import '../domain/chat_message.dart';
import '../domain/chat_session_repository.dart';

class InMemoryChatSessionRepository implements ChatSessionRepository {
  final Map<String, List<ChatMessage>> _sessions = {};
  final Map<String, DateTime> _updatedAt = {};
  final Set<String> _pinned = {};
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<ChatMessage>> load(String contextId) async =>
      List.unmodifiable(_sessions[contextId] ?? const []);

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {
    _sessions[contextId] = List.from(messages);
    _updatedAt[contextId] = DateTime.now();
    _changes.add(null);
  }

  @override
  Future<void> clear(String contextId) async {
    _sessions.remove(contextId);
    _updatedAt.remove(contextId);
    _pinned.remove(contextId);
    _changes.add(null);
  }

  @override
  Future<void> setPinned(String contextId, bool pinned) async {
    if (!_sessions.containsKey(contextId)) return;
    if (pinned) {
      _pinned.add(contextId);
    } else {
      _pinned.remove(contextId);
    }
    _changes.add(null);
  }

  @override
  Future<List<ChatSessionSummary>> listSessions() async {
    final result =
        _sessions.entries.where((entry) => entry.value.isNotEmpty).map(
      (entry) {
        final preview = entry.value.reversed
            .map((message) => message.content)
            .firstWhere((content) => content.trim().isNotEmpty,
                orElse: () => '');
        return ChatSessionSummary(
          contextId: entry.key,
          messageCount: entry.value.length,
          preview: preview,
          updatedAt:
              _updatedAt[entry.key] ?? DateTime.fromMillisecondsSinceEpoch(0),
          pinned: _pinned.contains(entry.key),
        );
      },
    ).toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
    return List.unmodifiable(result);
  }
}
