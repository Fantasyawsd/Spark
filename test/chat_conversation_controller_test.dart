import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/chat/application/chat_ai_service.dart';
import 'package:paperflow/src/features/chat/application/chat_conversation_controller.dart';
import 'package:paperflow/src/features/chat/application/main_ai_chat_definition.dart';
import 'package:paperflow/src/features/chat/domain/chat_context.dart';
import 'package:paperflow/src/features/chat/domain/chat_message.dart';

void main() {
  test('generic conversation sends its chat context to the AI service',
      () async {
    const context = ChatContext(
      id: 'general-chat',
      title: '通用聊天',
      systemPrompt: '回答科研问题。',
    );
    final service = _CapturingChatAiService();
    final controller = ChatConversationController(
      context: context,
      service: service,
    );

    expect(controller.reasoningEffort, ChatReasoningEffort.high);
    await controller.send('比较两种方法');

    expect(service.context, same(context));
    expect(service.conversation.single.content, '比较两种方法');
    expect(controller.messages.last.content, '通用回答');
    controller.dispose();
  });

  test('main chat owns a stable non-paper context and search prompt', () {
    final context = MainAiChatDefinition.context;

    expect(context.id, MainAiChatDefinition.sessionId);
    expect(context.title, 'PaperFlow 主聊天');
    expect(context.promptFor(webSearch: false), isNotEmpty);
    expect(context.promptFor(webSearch: true), contains('网络搜索'));
  });

  test('deleteMessagesAt removes selected messages in descending index order',
      () async {
    const context = ChatContext(
      id: 'delete-selected-messages-test',
      title: '批量删除测试',
      systemPrompt: '回答问题。',
    );
    final controller = ChatConversationController(
      context: context,
      service: _CapturingChatAiService(),
    );

    await controller.send('第一条问题');
    await controller.send('第二条问题');
    expect(controller.messages, hasLength(4));

    controller.deleteMessagesAt({1, 2});

    expect(controller.messages, hasLength(2));
    expect(controller.messages[0].content, '第一条问题');
    expect(controller.messages[1].content, '通用回答');
    controller.dispose();
  });

  test(
      'deleteMessageAt removes an assistant message without changing the user prompt',
      () async {
    const context = ChatContext(
      id: 'delete-message-test',
      title: '删除测试',
      systemPrompt: '回答问题。',
    );
    final controller = ChatConversationController(
      context: context,
      service: _CapturingChatAiService(),
    );

    await controller.send('保留这条问题');
    expect(controller.messages, hasLength(2));

    controller.deleteMessageAt(1);

    expect(controller.messages, hasLength(1));
    expect(controller.messages.single.content, '保留这条问题');
    controller.dispose();
  });
}

class _CapturingChatAiService implements ChatAiService {
  ChatContext? context;
  List<ChatMessage> conversation = const [];

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    this.context = context;
    this.conversation = conversation;
    return '通用回答';
  }
}
