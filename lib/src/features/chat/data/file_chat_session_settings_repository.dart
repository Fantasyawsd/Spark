import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/chat_session_settings.dart';

/// 会话级设置的 JSON 持久化：每个会话独立保存，schema 独立于聊天消息。
class FileChatSessionSettingsRepository
    implements ChatSessionSettingsRepository {
  FileChatSessionSettingsRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_ai_session_settings.json'),
          schemaId: 'papers.ai-session-settings',
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<ChatSessionSettings> load(String contextId) async {
    try {
      final json = await _store.readMap();
      if (json == null) return ChatSessionSettings.empty;
      final raw = json[contextId];
      if (raw is! Map) return ChatSessionSettings.empty;
      return ChatSessionSettingsJsonMapper.fromJson(
        Map<String, dynamic>.from(raw),
      );
    } catch (error) {
      throw ChatSessionSettingsPersistenceException(
        '无法读取会话设置。',
        error,
      );
    }
  }

  @override
  Future<void> save(String contextId, ChatSessionSettings settings) async {
    try {
      await _store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        json[contextId] = ChatSessionSettingsJsonMapper.toJson(settings);
        return json;
      });
    } catch (error) {
      throw ChatSessionSettingsPersistenceException(
        '无法保存会话设置。',
        error,
      );
    }
  }
}

class ChatSessionSettingsJsonMapper {
  const ChatSessionSettingsJsonMapper._();

  static Map<String, dynamic> toJson(ChatSessionSettings settings) {
    return {
      if (settings.customSystemPrompt?.trim().isNotEmpty ?? false)
        'customSystemPrompt': settings.customSystemPrompt!.trim(),
      'enabledSkillIds': settings.enabledSkillIds,
      'responseStyle': settings.responseStyle.name,
    };
  }

  static ChatSessionSettings fromJson(Map<String, dynamic> json) {
    final rawSkills = json['enabledSkillIds'];
    return ChatSessionSettings(
      customSystemPrompt: json['customSystemPrompt'] is String
          ? json['customSystemPrompt'] as String
          : null,
      enabledSkillIds: rawSkills is List
          ? rawSkills.whereType<String>().toList(growable: false)
          : const [],
      responseStyle: ChatResponseStyle.fromId(json['responseStyle'] as String?),
    );
  }
}
