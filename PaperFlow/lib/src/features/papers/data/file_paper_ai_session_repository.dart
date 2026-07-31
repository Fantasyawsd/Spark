import '../../../core/storage/local_json_store.dart';
import '../application/paper_ai_service.dart';
import '../application/paper_ai_session_repository.dart';

class FilePaperAiSessionRepository implements PaperAiSessionRepository {
  FilePaperAiSessionRepository({LocalJsonStore? store})
      : _store = store ?? LocalJsonStore(fileName: 'paper_ai_sessions.json');

  final LocalJsonStore _store;

  @override
  Future<List<PaperAiMessage>> load(String paperId) async {
    try {
      final json = await _store.read();
      if (json is! Map<String, dynamic>) return const [];
      final rawSession = json[paperId];
      final rawMessages =
          rawSession is Map ? rawSession['messages'] : rawSession;
      if (rawMessages is! List) return const [];
      return rawMessages
          .whereType<Map>()
          .map(
            (raw) => PaperAiMessage(
              fromUser: raw['fromUser'] == true,
              content: raw['content'] as String? ?? '',
              reasoningContent: raw['reasoningContent'] as String? ?? '',
              sources: _sourcesFromJson(raw['sources']),
            ),
          )
          .where((message) => message.content.trim().isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法读取 AI 对话记录。', error);
    }
  }

  @override
  Future<void> save(String paperId, List<PaperAiMessage> messages) async {
    try {
      final current = await _store.read();
      final json = current is Map<String, dynamic>
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};
      final previous = json[paperId];
      final pinned = previous is Map && previous['pinned'] == true;
      json[paperId] = {
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'pinned': pinned,
        'messages': messages.map(_messageToJson).toList(growable: false),
      };
      await _store.write(json);
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法保存 AI 对话记录。', error);
    }
  }

  @override
  Future<void> clear(String paperId) async {
    try {
      final current = await _store.read();
      if (current is! Map<String, dynamic>) return;
      final json = Map<String, dynamic>.from(current)..remove(paperId);
      await _store.write(json);
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法清空 AI 对话记录。', error);
    }
  }

  @override
  Future<void> setPinned(String paperId, bool pinned) async {
    try {
      final current = await _store.read();
      if (current is! Map<String, dynamic>) return;
      final json = Map<String, dynamic>.from(current);
      final rawSession = json[paperId];
      if (rawSession == null) return;
      if (rawSession is Map) {
        json[paperId] = Map<String, dynamic>.from(rawSession)
          ..['pinned'] = pinned;
      } else if (rawSession is List) {
        json[paperId] = {
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'pinned': pinned,
          'messages': rawSession,
        };
      }
      await _store.write(json);
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法更新 AI 会话置顶状态。', error);
    }
  }

  @override
  Future<List<PaperAiSessionSummary>> listSessions() async {
    try {
      final stored = await _store.read();
      if (stored is! Map<String, dynamic>) return const [];
      final result = <PaperAiSessionSummary>[];
      for (final entry in stored.entries) {
        final rawSession = entry.value;
        final rawMessages =
            rawSession is Map ? rawSession['messages'] : rawSession;
        if (rawMessages is! List || rawMessages.isEmpty) continue;
        final messages = rawMessages.whereType<Map>().toList(growable: false);
        if (messages.isEmpty) continue;
        final preview = messages.reversed
            .map((item) => item['content'] as String? ?? '')
            .firstWhere((text) => text.trim().isNotEmpty, orElse: () => '');
        if (preview.isEmpty) continue;
        final rawUpdatedAt =
            rawSession is Map ? rawSession['updatedAt'] as String? : null;
        result.add(
          PaperAiSessionSummary(
            paperId: entry.key,
            messageCount: messages.length,
            preview: preview.trim(),
            updatedAt: DateTime.tryParse(rawUpdatedAt ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            pinned: rawSession is Map && rawSession['pinned'] == true,
          ),
        );
      }
      result.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return List.unmodifiable(result);
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法读取 AI 会话列表。', error);
    }
  }

  static Map<String, Object> _messageToJson(PaperAiMessage message) {
    return {
      'fromUser': message.fromUser,
      'content': message.content,
      'reasoningContent': message.reasoningContent,
      'sources': [
        for (final source in message.sources)
          {'title': source.title, 'url': source.url},
      ],
    };
  }

  static List<PaperAiSource> _sourcesFromJson(Object? rawSources) {
    if (rawSources is! List) return const [];
    return rawSources.whereType<Map>().map((raw) {
      return PaperAiSource(
        title: raw['title'] as String? ?? '',
        url: raw['url'] as String? ?? '',
      );
    }).where((source) {
      return source.title.trim().isNotEmpty && source.url.trim().isNotEmpty;
    }).toList(growable: false);
  }
}
