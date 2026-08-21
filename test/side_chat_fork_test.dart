import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/domain/side_chat_fork.dart';

void main() {
  const mainContext = ChatContext(
    id: 'spark-main-ai-chat',
    title: 'Spark 主聊天',
    subtitle: 'Spark AI',
    systemPrompt: '你是 Spark 主助手。',
    webSearchSystemPrompt: '你是 Spark 主助手（联网）。',
  );

  test('fork 使用固定临时 id 且标题追加后缀', () {
    final side =
        SideChatFork.create(mainContext: mainContext, messages: const []);
    expect(side.id, SideChatFork.sideChatId);
    expect(side.title, 'Spark 主聊天（临时聊天）');
    expect(side.subtitle, '临时会话 · 退出不保存');
    expect(side.id, isNot(mainContext.id));
  });

  test('空消息不注入背景，systemPrompt 保持原样', () {
    final side =
        SideChatFork.create(mainContext: mainContext, messages: const []);
    expect(side.systemPrompt, '你是 Spark 主助手。');
    expect(side.webSearchSystemPrompt, '你是 Spark 主助手（联网）。');
  });

  test('有消息时背景注入 systemPrompt', () {
    final side = SideChatFork.create(
      mainContext: mainContext,
      messages: const [
        ChatMessage(fromUser: true, content: '什么是 Transformer？'),
        ChatMessage(fromUser: false, content: 'Transformer 是一种注意力机制模型。'),
      ],
    );
    expect(side.systemPrompt, contains('你是 Spark 主助手。'));
    expect(side.systemPrompt, contains('[用户] 什么是 Transformer？'));
    expect(side.systemPrompt, contains('[助手] Transformer 是一种注意力机制模型。'));
    expect(side.systemPrompt, contains('主聊天的背景信息'));
  });

  test('webSearchSystemPrompt 同步注入背景', () {
    final side = SideChatFork.create(
      mainContext: mainContext,
      messages: const [ChatMessage(fromUser: true, content: 'hello')],
    );
    expect(side.webSearchSystemPrompt, contains('（联网）'));
    expect(side.webSearchSystemPrompt, contains('[用户] hello'));
  });

  test('无 webSearchSystemPrompt 时保持 null', () {
    const noSearchContext = ChatContext(
      id: 'spark-main-ai-chat',
      title: 'Spark 主聊天',
      systemPrompt: 'prompt',
    );
    final side = SideChatFork.create(
      mainContext: noSearchContext,
      messages: const [ChatMessage(fromUser: true, content: 'hi')],
    );
    expect(side.webSearchSystemPrompt, isNull);
  });

  test('空内容消息不进入背景', () {
    final side = SideChatFork.create(
      mainContext: mainContext,
      messages: const [
        ChatMessage(fromUser: true, content: '  '),
        ChatMessage(fromUser: false, content: '有效回复'),
      ],
    );
    expect(side.systemPrompt, contains('[助手] 有效回复'));
    expect(side.systemPrompt, isNot(contains('[用户]')));
  });

  test('单条超长消息被截断', () {
    final long = 'a' * 2000;
    final side = SideChatFork.create(
      mainContext: mainContext,
      messages: [ChatMessage(fromUser: true, content: long)],
    );
    // 单条截断 800，整体 6000，不应包含完整 2000 字符
    expect(side.systemPrompt.length, lessThan('你是 Spark 主助手。'.length + 7000));
    expect(side.systemPrompt, contains('…'));
  });

  test('fork 不修改原始 messages（快照语义）', () {
    final messages = [const ChatMessage(fromUser: true, content: 'before')];
    final side =
        SideChatFork.create(mainContext: mainContext, messages: messages);
    // 调用后原始列表未被修改
    expect(messages, hasLength(1));
    expect(side.systemPrompt, contains('before'));
  });
}
