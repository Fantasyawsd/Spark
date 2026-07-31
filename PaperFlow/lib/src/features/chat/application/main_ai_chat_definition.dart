import '../../papers/domain/paper.dart';

/// Stable identity and prompt configuration for the app-wide AI conversation.
///
/// The current AI service API is paper-oriented, so [contextRecord] supplies a
/// private context record. It is never shown as a paper and its stable id keeps
/// the main conversation separate from per-paper sessions.
class MainAiChatDefinition {
  const MainAiChatDefinition._();

  static const sessionId = 'paperflow-main-ai-chat';

  static const contextRecord = PaperRecord(
    id: sessionId,
    venue: 'PaperFlow',
    title: 'PaperFlow 主聊天',
    authors: 'PaperFlow AI',
    firstAffiliation: 'PaperFlow',
    topics: ['Research Assistant'],
    abstractText: '',
    chineseAbstractMarkdown: '',
    relatedPapers: [],
    readMinutes: 0,
    citations: '0',
    likes: '0',
    comments: '0',
    saves: '0',
    shares: '0',
    source: 'system',
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
