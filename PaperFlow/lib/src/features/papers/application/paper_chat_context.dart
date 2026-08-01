import '../../chat/domain/chat_context.dart';
import '../domain/paper.dart';
import 'paper_ai_prompt_builder.dart';

class PaperChatContext {
  const PaperChatContext._();

  static ChatContext fromPaper(PaperRecord paper) {
    return ChatContext(
      id: paper.id,
      title: paper.title,
      subtitle: '${paper.authors.split(',').first.trim()} · ${paper.venue}',
      systemPrompt: PaperAiPromptBuilder.systemPrompt(paper),
      webSearchSystemPrompt: PaperAiPromptBuilder.systemPrompt(
        paper,
        webSearch: true,
      ),
    );
  }
}
