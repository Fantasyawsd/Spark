import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/application/main_ai_chat_definition.dart';
import 'package:spark/src/features/papers/application/paper_chat_context.dart';
import 'package:spark/src/features/papers/domain/paper.dart';

/// 主聊天、论文聊天与论文派生缓存的数据边界：
/// - 主聊天永不注入论文派生数据；
/// - 论文聊天以论文 id 为会话身份，只注入当前论文的元数据与有效缓存关键词；
/// - 派生数据只作为 systemPrompt 背景，不进入聊天消息。
void main() {
  test('main chat keeps a fixed identity and never injects paper derived data',
      () {
    final context = MainAiChatDefinition.context;

    expect(context.id, MainAiChatDefinition.sessionId);
    expect(context.systemPrompt, contains('主 AI 助手'));
    expect(context.systemPrompt, isNot(contains('内容关键词')));
    expect(context.systemPrompt, isNot(contains('static-subject')));
  });

  test(
      'paper chat binds the session id to the paper and injects only valid '
      'cached keywords', () {
    final paper = _paper();
    final context = PaperChatContext.fromPaper(
      paper,
      generatedKeywords: const ['retrieval'],
    );

    expect(context.id, paper.id);
    expect(context.title, paper.title);
    expect(context.systemPrompt, contains(paper.title));
    expect(context.systemPrompt, contains('内容关键词：retrieval'));
    expect(context.systemPrompt, isNot(contains('static-subject')));
  });

  test('paper chat stays independent from the main chat namespace', () {
    final paper = _paper();
    final paperContext = PaperChatContext.fromPaper(paper);
    final mainContext = MainAiChatDefinition.context;

    expect(paperContext.id, isNot(mainContext.id));
    expect(paperContext.systemPrompt, isNot(mainContext.systemPrompt));
  });
}

Paper _paper() => Paper(
      id: 'paper-boundary-1',
      title: 'Boundary paper',
      authors: ['Author'],
      contentKeywords: ['static-subject'],
      subjects: ['cs.AI'],
      abstractText: 'Abstract text.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
    );
