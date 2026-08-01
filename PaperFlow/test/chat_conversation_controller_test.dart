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
