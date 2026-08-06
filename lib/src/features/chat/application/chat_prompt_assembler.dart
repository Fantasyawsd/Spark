import '../domain/chat_context.dart';
import '../domain/chat_session_settings.dart';
import 'chat_skills.dart';

/// 把会话级设置组装进最终 system prompt。
///
/// 规则：
/// - 自定义系统提示词非空时替换默认 system prompt（用户完全控制）；
/// - 回答风格与启用的技能始终追加在基础提示词之后；
/// - webSearchSystemPrompt 同步应用同样的设置，避免联网与非联网行为不一致。
class ChatPromptAssembler {
  const ChatPromptAssembler._();

  static ChatContext applySettings(
    ChatContext context,
    ChatSessionSettings settings,
  ) {
    // 无自定义时保持原 context 身份，避免无谓重建。
    if (!settings.hasCustomizations) return context;

    final basePrompt = settings.customSystemPrompt?.trim().isNotEmpty ?? false
        ? settings.customSystemPrompt!.trim()
        : context.systemPrompt;
    final baseWebSearch =
        settings.customSystemPrompt?.trim().isNotEmpty ?? false
            ? settings.customSystemPrompt!.trim()
            : context.promptFor(webSearch: true);

    return ChatContext(
      id: context.id,
      title: context.title,
      subtitle: context.subtitle,
      systemPrompt: _withExtras(basePrompt, settings),
      webSearchSystemPrompt: _withExtras(baseWebSearch, settings),
    );
  }

  static String _withExtras(
    String basePrompt,
    ChatSessionSettings settings,
  ) {
    final buffer = StringBuffer(basePrompt.trim());
    if (settings.responseStyle != ChatResponseStyle.balanced) {
      buffer.write('\n\n${settings.responseStyle.instruction}');
    }
    for (final skillId in settings.enabledSkillIds) {
      final skill = ChatSkills.byId(skillId);
      if (skill != null) buffer.write('\n\n${skill.prompt}');
    }
    return buffer.toString();
  }
}
