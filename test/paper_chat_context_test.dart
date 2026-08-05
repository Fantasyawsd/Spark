import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/papers/application/paper_ai_prompt_builder.dart';
import 'package:paperflow/src/features/papers/application/paper_chat_context.dart';
import 'package:paperflow/src/features/papers/domain/paper.dart';

void main() {
  test('ChatPaper includes only explicitly supplied generated keywords', () {
    final paper = _paper(contentKeywords: const ['static-subject']);

    final context = PaperChatContext.fromPaper(
      paper,
      generatedKeywords: const ['retrieval', 'agents', 'evaluation'],
    );

    expect(
        context.systemPrompt, contains('内容关键词：retrieval, agents, evaluation'));
    expect(context.systemPrompt, isNot(contains('static-subject')));
  });

  test('ChatPaper marks keywords unknown when no valid cache was supplied', () {
    final prompt = PaperAiPromptBuilder.systemPrompt(
      _paper(contentKeywords: const ['static-subject']),
    );

    expect(prompt, contains('内容关键词：未知'));
    expect(prompt, isNot(contains('static-subject')));
  });
}

Paper _paper({List<String> contentKeywords = const []}) => Paper(
      id: 'paper-1',
      title: 'Paper title',
      authors: const ['Author'],
      contentKeywords: contentKeywords,
      subjects: const ['cs.AI'],
      abstractText: 'Abstract text.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
    );
