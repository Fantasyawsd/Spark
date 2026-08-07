/// 回答风格偏好：会话级个性化设置，影响最终 system prompt 的措辞。
enum ChatResponseStyle {
  concise('简洁', '回答尽量简短，直接给出要点，减少铺垫。'),
  balanced('均衡', '回答保持准确与清晰，兼顾完整性与简洁性。'),
  detailed('详细', '回答尽量详细，展开解释背景、推理过程和示例。');

  const ChatResponseStyle(this.label, this.instruction);

  final String label;
  final String instruction;

  static ChatResponseStyle fromId(String? id) {
    return values.firstWhere(
      (style) => style.name == id,
      orElse: () => ChatResponseStyle.balanced,
    );
  }
}

/// 可组合技能：一段可注入 system prompt 的能力描述。
class ChatSkill {
  const ChatSkill({
    required this.id,
    required this.name,
    required this.prompt,
    this.description,
  });

  final String id;
  final String name;
  final String prompt;
  final String? description;
}

/// 会话级设置：自定义系统提示词、启用的技能与回答风格。
class ChatSessionSettings {
  const ChatSessionSettings({
    this.customSystemPrompt,
    this.enabledSkillIds = const [],
    this.responseStyle = ChatResponseStyle.balanced,
  });

  final String? customSystemPrompt;
  final List<String> enabledSkillIds;
  final ChatResponseStyle responseStyle;

  bool get hasCustomizations =>
      (customSystemPrompt?.trim().isNotEmpty ?? false) ||
      enabledSkillIds.isNotEmpty ||
      responseStyle != ChatResponseStyle.balanced;

  ChatSessionSettings copyWith({
    String? customSystemPrompt,
    bool clearCustomSystemPrompt = false,
    List<String>? enabledSkillIds,
    ChatResponseStyle? responseStyle,
  }) {
    return ChatSessionSettings(
      customSystemPrompt: clearCustomSystemPrompt
          ? null
          : customSystemPrompt ?? this.customSystemPrompt,
      enabledSkillIds: enabledSkillIds ?? this.enabledSkillIds,
      responseStyle: responseStyle ?? this.responseStyle,
    );
  }

  static const empty = ChatSessionSettings();
}

/// 会话设置的持久化边界：每个会话独立保存，不进入聊天消息。
abstract interface class ChatSessionSettingsRepository {
  Future<ChatSessionSettings> load(String contextId);

  Future<void> save(String contextId, ChatSessionSettings settings);

  Future<void> clear(String contextId);
}

class ChatSessionSettingsPersistenceException implements Exception {
  const ChatSessionSettingsPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
