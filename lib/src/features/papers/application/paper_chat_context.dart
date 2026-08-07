import '../../chat/chat.dart';
import '../domain/paper.dart';
import 'paper_ai_prompt_builder.dart';

class PaperChatContext {
  const PaperChatContext._();

  static ChatContext fromPaper(
    Paper paper, {
    List<String> generatedKeywords = const [],
    String? pdfContext,
  }) {
    final keywords = generatedKeywords;
    final venue = paper.venue ?? paper.journalReference;
    final subtitle =
        venue == null ? paper.firstAuthor : '${paper.firstAuthor} · $venue';
    return ChatContext(
      id: paper.id,
      title: paper.title,
      subtitle: subtitle,
      systemPrompt: PaperAiPromptBuilder.systemPrompt(
        paper,
        generatedKeywords: keywords,
        pdfContext: pdfContext,
      ),
      webSearchSystemPrompt: PaperAiPromptBuilder.systemPrompt(
        paper,
        webSearch: true,
        generatedKeywords: keywords,
        pdfContext: pdfContext,
      ),
    );
  }
}
