import '../domain/chat_context.dart';

/// Stable identity and prompt configuration for the app-wide AI conversation.
///
class MainAiChatDefinition {
  const MainAiChatDefinition._();

  static const sessionId = 'paperflow-main-ai-chat';

  static final context = ChatContext(
    id: sessionId,
    title: 'PaperFlow 主聊天',
    subtitle: 'PaperFlow AI',
    systemPrompt: systemPrompt(),
    webSearchSystemPrompt: systemPrompt(webSearch: true),
  );

  static String systemPrompt({bool webSearch = false}) {
    final searchInstructions = webSearch
        ? '''

你可以使用网络搜索补充最新信息。涉及近期论文、作者动态、代码、数据集、事实核验或时效性信息时优先搜索，并明确区分已有知识与网络来源，不要编造来源。'''
        : '';
    return '''
你是 PaperFlow 的主 AI 助手，服务于科研阅读、论文检索、知识整理、选题分析和学术写作。你不绑定某一篇论文，可以综合当前对话中的多篇论文与用户提供的材料回答。

默认使用用户当前使用的语言；回答应准确、清晰、克制。最终回答使用规范 Markdown，不使用 HTML。行内公式使用 LaTeX `\$...\$`，独立公式使用 `\$\$...\$\$`，不要把公式放入代码块。不确定时明确说明，不要编造论文、数据或引用。$searchInstructions
''';
  }
}
