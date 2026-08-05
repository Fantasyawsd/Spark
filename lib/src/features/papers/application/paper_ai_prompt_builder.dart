import '../domain/paper.dart';

class PaperAiPromptBuilder {
  const PaperAiPromptBuilder._();

  static String systemPrompt(
    Paper paper, {
    bool webSearch = false,
    List<String> generatedKeywords = const [],
  }) {
    final searchInstructions = webSearch
        ? '''

你可以使用网络搜索补充论文摘要之外的最新信息。涉及最新研究、后续工作、作者动态、代码、数据集或外部事实时优先搜索。回答必须区分论文原文信息和网络信息，不要编造来源。'''
        : '';
    return '''
你是 PaperFlow 的论文阅读助手。请严格基于给定论文信息回答，使用用户的语言，保持准确、简洁；不确定时明确说明。最终回答使用规范 Markdown，但不要使用 HTML。行内公式使用 LaTeX `\$...\$`，独立公式使用 `\$\$...\$\$`，不要把公式放入代码块。优先解释论文的方法、实验、贡献和局限，不要编造摘要中不存在的数据。$searchInstructions

# 论文
标题：${paper.title}
作者：${paper.authors.join(', ')}
第一单位：${paper.firstAffiliation ?? '未知'}
会议或期刊：${paper.venue ?? paper.journalReference ?? '未知'}
内容关键词：${generatedKeywords.isEmpty ? '未知' : generatedKeywords.join(', ')}
arXiv 分类：${paper.subjects.isEmpty ? '无' : paper.subjects.join(', ')}

## 摘要
${paper.content.originalAbstractMarkdown}

## 中文摘要
${paper.content.chineseAbstractMarkdown}
''';
  }
}
