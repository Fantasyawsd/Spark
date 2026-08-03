import 'dart:async';

import '../../chat/domain/chat_message.dart';
import '../../chat/domain/chat_session_repository.dart';

class InMemoryPaperAiSessionRepository implements ChatSessionRepository {
  final Map<String, List<ChatMessage>> _sessions = {};
  final Map<String, DateTime> _updatedAt = {};
  final Set<String> _pinned = {};
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<ChatMessage>> load(String paperId) async =>
      List.unmodifiable(_sessions[paperId] ?? const []);

  @override
  Future<void> save(String paperId, List<ChatMessage> messages) async {
    _sessions[paperId] = List.from(messages);
    _updatedAt[paperId] = DateTime.now();
    _changes.add(null);
  }

  @override
  Future<void> clear(String paperId) async {
    _sessions.remove(paperId);
    _updatedAt.remove(paperId);
    _pinned.remove(paperId);
    _changes.add(null);
  }

  @override
  Future<void> setPinned(String paperId, bool pinned) async {
    if (!_sessions.containsKey(paperId)) return;
    if (pinned) {
      _pinned.add(paperId);
    } else {
      _pinned.remove(paperId);
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
