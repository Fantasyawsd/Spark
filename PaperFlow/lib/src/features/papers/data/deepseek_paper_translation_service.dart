import '../../chat/domain/chat_context.dart';
import '../../chat/application/chat_ai_service.dart';
import '../../chat/domain/chat_message.dart';
import '../application/paper_translation_service.dart';
import '../domain/paper.dart';
import 'deepseek_paper_ai_service.dart';

class DeepSeekPaperTranslationService implements PaperTranslationService {
  DeepSeekPaperTranslationService({DeepSeekPaperAiService? client})
      : _client = client ?? DeepSeekPaperAiService(thinkingEnabled: false);

  final DeepSeekPaperAiService _client;

  @override
  Stream<String> translateAbstract(Paper paper) async* {
    try {
      await for (final chunk in _client.answerStream(
        context: ChatContext(
          id: 'translation:${paper.id}',
          title: paper.title,
          systemPrompt: '你是论文摘要翻译助手，只输出忠实、专业的简体中文译文。',
        ),
        conversation: [
          ChatMessage(
            fromUser: true,
            content: '''
请将下面的英文论文摘要忠实翻译为简体中文。

要求：
- 保留原文的技术含义、术语、数字和逻辑关系。
- 不增加总结、评价、标题或原文中不存在的信息。
- 使用自然、专业的学术中文。
- 只输出译文，可使用 Markdown 保留原文列表结构。
- 保留原有公式；行内公式使用 LaTeX `\$...\$`，独立公式使用 `\$\$...\$\$`，不要把公式放入代码块。

${paper.content.originalAbstractMarkdown}
''',
          ),
        ],
      )) {
        if (chunk.contentDelta.isNotEmpty) yield chunk.contentDelta;
      }
    } on ChatAiException catch (error) {
      throw PaperTranslationException(error.message);
    }
  }

  @override
  void cancelActiveTranslation() => _client.cancelActiveRequest();
}

class DeepSeekPaperTranslationServiceFactory
    implements PaperTranslationServiceFactory {
  const DeepSeekPaperTranslationServiceFactory();

  @override
  PaperTranslationService create() => DeepSeekPaperTranslationService();
}
