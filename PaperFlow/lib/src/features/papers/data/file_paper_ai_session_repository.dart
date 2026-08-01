import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../application/paper_ai_service.dart';
import '../application/paper_ai_session_repository.dart';
import 'paper_ai_session_json_mapper.dart';

class FilePaperAiSessionRepository implements PaperAiSessionRepository {
  FilePaperAiSessionRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_ai_sessions.json'),
          schemaId: 'papers.ai-sessions',
          validatePayload: PaperAiSessionJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<List<PaperAiMessage>> load(String paperId) async {
    try {
      final json = await _store.readMap();
      if (json == null) return const [];
      return PaperAiSessionJsonMapper.messagesFor(json, paperId);
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法读取 AI 对话记录。', error);
    }
  }

  @override
  Future<void> save(String paperId, List<PaperAiMessage> messages) async {
    try {
      await _store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        final previous = json[paperId];
        final pinned = PaperAiSessionJsonMapper.isPinned(previous);
        json[paperId] = {
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'pinned': pinned,
          'messages': messages
              .map(PaperAiSessionJsonMapper.toJson)
              .toList(growable: false),
        };
        return json;
      });
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法保存 AI 对话记录。', error);
    }
  }

  @override
  Future<void> clear(String paperId) async {
    try {
      await _store.updateMap((json) {
        if (json == null) return null;
        json.remove(paperId);
        return json;
      });
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法清空 AI 对话记录。', error);
    }
  }

  @override
  Future<void> setPinned(String paperId, bool pinned) async {
    try {
      await _store.updateMap((json) {
        if (json == null) return null;
        final rawSession = json[paperId];
        if (rawSession == null) return null;
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
        return json;
      });
    } catch (error) {
      throw PaperAiSessionPersistenceException('无法更新 AI 会话置顶状态。', error);
    }
  }

  @override
  Future<List<PaperAiSessionSummary>> listSessions() async {
    try {
      final stored = await _store.readMap();
      if (stored == null) return const [];
      final result = <PaperAiSessionSummary>[];
      for (final entry in stored.entries) {
        final rawSession = entry.value;
        final rawMessages = PaperAiSessionJsonMapper.rawMessages(rawSession);
        if (rawMessages is! List || rawMessages.isEmpty) continue;
        final messages = rawMessages
            .map((raw) => PaperAiSessionJsonMapper.fromJson(
                  Map<String, dynamic>.from(raw as Map),
                ))
            .where(PaperAiSessionJsonMapper.hasPersistableContent)
            .toList(growable: false);
        if (messages.isEmpty) continue;
        final preview = messages.reversed
            .map((item) => item.content)
            .firstWhere((text) => text.trim().isNotEmpty, orElse: () => '');
        if (preview.isEmpty) continue;
        result.add(
          PaperAiSessionSummary(
            contextId: entry.key,
            messageCount: messages.length,
            preview: preview.trim(),
            updatedAt: PaperAiSessionJsonMapper.updatedAt(rawSession),
            pinned: PaperAiSessionJsonMapper.isPinned(rawSession),
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
}
