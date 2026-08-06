import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/application/chat_ai_service.dart';
import 'package:spark/src/features/chat/application/chat_conversation_controller.dart';
import 'package:spark/src/features/chat/application/main_ai_chat_definition.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/domain/chat_session_repository.dart';

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

  test(
      'completed latest assistant can be regenerated without duplicating prompt',
      () async {
    const context = ChatContext(
      id: 'completed-retry-test',
      title: '完成态重试测试',
      systemPrompt: '回答问题。',
    );
    final service = _QueueChatAiService(['第一次回答', '第二次回答']);
    final controller = ChatConversationController(
      context: context,
      service: service,
    );

    await controller.send('原始问题');
    expect(controller.canRetry, isFalse);

    await controller.retry();

    expect(controller.messages.map((message) => message.content), [
      '原始问题',
      '第二次回答',
    ]);
    expect(service.conversations, hasLength(2));
    expect(
      service.conversations.every(
        (conversation) =>
            conversation.where((message) => message.fromUser).length == 1,
      ),
      isTrue,
    );
    controller.dispose();
  });

  test('editing latest prompt replaces its old answer before regenerating',
      () async {
    const context = ChatContext(
      id: 'edit-prompt-test',
      title: '编辑 Prompt 测试',
      systemPrompt: '回答问题。',
    );
    final service = _QueueChatAiService(['旧回答', '新回答']);
    final controller = ChatConversationController(
      context: context,
      service: service,
    );

    await controller.send('旧问题');
    await controller.editLatestPromptAndRetry('修改后的问题');

    expect(controller.messages.map((message) => message.content), [
      '修改后的问题',
      '新回答',
    ]);
    expect(
      service.conversations.last.map((message) => message.content),
      ['修改后的问题'],
    );
    controller.dispose();
  });

  test(
      'retry after restoring a user-only failed session does not append prompt',
      () async {
    const context = ChatContext(
      id: 'restored-user-only-retry-test',
      title: '恢复重试测试',
      systemPrompt: '回答问题。',
    );
    final service = _QueueChatAiService(['恢复后的回答']);
    final repository = _FixedChatSessionRepository([
      const ChatMessage(fromUser: true, content: '待重试问题'),
    ]);
    final controller = ChatConversationController(
      context: context,
      service: service,
      sessionRepository: repository,
    );

    await controller.initialize();
    expect(controller.canRetryRequestError, isTrue);

    await controller.retry();

    expect(controller.messages.map((message) => message.content), [
      '待重试问题',
      '恢复后的回答',
    ]);
    expect(service.conversations.single.map((message) => message.content), [
      '待重试问题',
    ]);
    controller.dispose();
  });

  test('main chat owns a stable non-paper context and search prompt', () {
    final context = MainAiChatDefinition.context;

    expect(context.id, MainAiChatDefinition.sessionId);
    expect(context.title, 'Spark 主聊天');
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

class _QueueChatAiService implements ChatAiService {
  _QueueChatAiService(this.results);

  final List<String> results;
  final List<List<ChatMessage>> conversations = [];

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    conversations.add(List<ChatMessage>.from(conversation));
    return results.removeAt(0);
  }
}

class _FixedChatSessionRepository implements ChatSessionRepository {
  const _FixedChatSessionRepository(this.messages);

  final List<ChatMessage> messages;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<List<ChatMessage>> load(String contextId) async => messages;

  @override
  Future<List<ChatSessionSummary>> listSessions() async => const [];

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}
