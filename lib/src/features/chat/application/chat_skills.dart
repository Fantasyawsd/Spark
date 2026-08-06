import '../domain/chat_session_settings.dart';

/// 内置可组合技能目录。技能描述只影响 system prompt，不触碰消息内容。
class ChatSkills {
  const ChatSkills._();

  static const all = <ChatSkill>[
    ChatSkill(
      id: 'rigorous-citation',
      name: '严谨引用',
      description: '要求引用必须可溯源，不编造来源',
      prompt: '涉及论文、数据或事实时，只引用你确知存在的来源；无法确证时明确说明不确定，绝不编造引用或链接。',
    ),
    ChatSkill(
      id: 'math-derivation',
      name: '数学推导',
      description: '给出完整的公式推导过程',
      prompt: '涉及数学推导时，逐步展示中间过程和关键假设；使用 LaTeX 行内公式与独立公式，不把公式放入代码块。',
    ),
    ChatSkill(
      id: 'code-assist',
      name: '代码辅助',
      description: '提供可直接运行的代码与解释',
      prompt: '提供代码时给出完整可运行的片段，并简要解释关键步骤；优先使用 Python 与常见科研库。',
    ),
    ChatSkill(
      id: 'paper-critique',
      name: '论文批判',
      description: '分析论文方法的局限与改进空间',
      prompt: '在总结论文时主动指出方法局限、实验不足与可改进方向，并区分作者观点与你自己的分析。',
    ),
  ];

  static ChatSkill? byId(String id) {
    for (final skill in all) {
      if (skill.id == id) return skill;
    }
    return null;
  }
}
