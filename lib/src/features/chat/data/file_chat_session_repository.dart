import 'dart:async';

import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/chat_message.dart';
import '../domain/chat_session_repository.dart';
import 'chat_session_json_mapper.dart';

class FileChatSessionRepository implements ChatSessionRepository {
  FileChatSessionRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'chat_sessions.json'),
          schemaId: 'chat.sessions',
          validatePayload: ChatSessionJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<ChatMessage>> load(String contextId) async {
    try {
      final json = await _store.readMap();
      if (json == null) return const [];
      return ChatSessionJsonMapper.messagesFor(json, contextId);
    } catch (error) {
      throw ChatSessionPersistenceException('无法读取 AI 对话记录。', error);
    }
  }

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {
    try {
      await _store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        final previous = json[contextId];
        final pinned = ChatSessionJsonMapper.isPinned(previous);
        json[contextId] = {
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'pinned': pinned,
          'messages': messages
              .map(ChatSessionJsonMapper.toJson)
              .toList(growable: false),
        };
        return json;
      });
      _changes.add(null);
    } catch (error) {
      throw ChatSessionPersistenceException('无法保存 AI 对话记录。', error);
    }
  }

  @override
  Future<void> clear(String contextId) async {
    try {
      await _store.updateMap((json) {
        if (json == null) return null;
        json.remove(contextId);
        return json;
      });
      _changes.add(null);
    } catch (error) {
      throw ChatSessionPersistenceException('无法清空 AI 对话记录。', error);
    }
  }

  @override
  Future<void> setPinned(String contextId, bool pinned) async {
    try {
      await _store.updateMap((json) {
        if (json == null) return null;
        final rawSession = json[contextId];
        if (rawSession == null) return null;
        if (rawSession is Map) {
          json[contextId] = Map<String, dynamic>.from(rawSession)
            ..['pinned'] = pinned;
        } else if (rawSession is List) {
          json[contextId] = {
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            'pinned': pinned,
            'messages': rawSession,
          };
        }
        return json;
      });
      _changes.add(null);
    } catch (error) {
      throw ChatSessionPersistenceException('无法更新 AI 会话置顶状态。', error);
    }
  }

  @override
  Future<List<ChatSessionSummary>> listSessions() async {
    try {
      final stored = await _store.readMap();
      if (stored == null) return const [];
      final result = <ChatSessionSummary>[];
      for (final entry in stored.entries) {
        final rawSession = entry.value;
        final rawMessages = ChatSessionJsonMapper.rawMessages(rawSession);
        if (rawMessages is! List || rawMessages.isEmpty) continue;
        final messages = rawMessages
            .map((raw) => ChatSessionJsonMapper.fromJson(
                  Map<String, dynamic>.from(raw as Map),
                ))
            .where(ChatSessionJsonMapper.hasPersistableContent)
            .toList(growable: false);
        if (messages.isEmpty) continue;
        final preview = messages.reversed
            .map((item) => item.content)
            .firstWhere((text) => text.trim().isNotEmpty, orElse: () => '');
        if (preview.isEmpty) continue;
        result.add(
          ChatSessionSummary(
            contextId: entry.key,
            messageCount: messages.length,
            preview: preview.trim(),
            updatedAt: ChatSessionJsonMapper.updatedAt(rawSession),
            pinned: ChatSessionJsonMapper.isPinned(rawSession),
          ),
        );
      }
      result.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return List.unmodifiable(result);
    } catch (error) {
      throw ChatSessionPersistenceException('无法读取 AI 会话列表。', error);
    }
  }
}
