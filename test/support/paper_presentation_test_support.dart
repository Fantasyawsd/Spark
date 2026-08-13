import 'package:spark/spark.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_discussion_view.dart';
import 'package:spark/src/features/papers/application/paper_chat_context.dart';
import 'package:spark/src/features/papers/presentation/paper_ai_discussion_builder.dart';

PaperAiDiscussionBuilder paperAiDiscussionBuilder(ChatAiService service) {
  return (
    context, {
    required paper,
    required generatedKeywords,
    required scrollController,
  }) {
    return PaperAiDiscussionView(
      chatContext: PaperChatContext.fromPaper(
        paper,
        generatedKeywords: generatedKeywords,
      ),
      aiService: service,
      scrollController: scrollController,
    );
  };
}

class FakeChatAiService implements ChatAiService {
  const FakeChatAiService();

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return '**DeepSeek Markdown**\n\n- ${context.title}\n- ${conversation.last.content}';
  }
}

class FakePaperTranslationServiceFactory
    implements PaperTranslationServiceFactory {
  const FakePaperTranslationServiceFactory({
    this.content = '**中文摘要内容**',
    this.delay = Duration.zero,
  });

  final String content;
  final Duration delay;

  @override
  PaperTranslationService create() =>
      FakePaperTranslationService(content, delay: delay);
}

class FakePaperTranslationService implements PaperTranslationService {
  const FakePaperTranslationService(this.content, {required this.delay});

  final String content;
  final Duration delay;

  @override
  Stream<String> translateAbstract(Paper paper) async* {
    await Future<void>.delayed(delay);
    yield content;
  }

  @override
  void cancelActiveTranslation() {}
}
