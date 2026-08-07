import '../../chat/chat.dart';
import '../domain/paper.dart';
import '../domain/paper_translation.dart';

class DeepSeekPaperTranslationService implements PaperTranslationService {
  DeepSeekPaperTranslationService({
    required RequestScopedStreamingChatAiService client,
  }) : _client = client;

  final RequestScopedStreamingChatAiService _client;
  ChatRequestCancellation? _activeCancellation;

  @override
  Stream<String> translateAbstract(Paper paper) async* {
    final cancellation = ChatRequestCancellation();
    _activeCancellation = cancellation;
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
        cancellation: cancellation,
      )) {
        if (chunk.contentDelta.isNotEmpty) yield chunk.contentDelta;
      }
    } on ChatAiException catch (error) {
      throw PaperTranslationException(error.message);
    } finally {
      if (identical(_activeCancellation, cancellation)) {
        _activeCancellation = null;
      }
    }
  }

  @override
  void cancelActiveTranslation() => _activeCancellation?.cancel();
}

class DeepSeekPaperTranslationServiceFactory
    implements PaperTranslationServiceFactory {
  const DeepSeekPaperTranslationServiceFactory({
    required this.chatClientFactory,
  });

  final RequestScopedStreamingChatAiService Function() chatClientFactory;

  @override
  PaperTranslationService create() => DeepSeekPaperTranslationService(
        client: chatClientFactory(),
      );
}
