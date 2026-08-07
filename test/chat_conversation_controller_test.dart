import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/application/chat_conversation_controller.dart';
import 'package:spark/src/features/chat/application/main_ai_chat_definition.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/domain/chat_session_repository.dart';
import 'package:spark/src/features/chat/domain/chat_session_settings.dart';

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

  test('a new request omits partial cancelled assistant content from context',
      () async {
    const context = ChatContext(
      id: 'cancelled-context-test',
      title: '取消上下文测试',
      systemPrompt: '回答问题。',
    );
    final service = _QueueChatAiService(['新回答']);
    final controller = ChatConversationController(
      context: context,
      service: service,
      sessionRepository: const _FixedChatSessionRepository([
        ChatMessage(fromUser: true, content: '旧问题'),
        ChatMessage(
          fromUser: false,
          content: '未完成的部分回答',
          status: ChatMessageStatus.cancelled,
        ),
      ]),
    );

    await controller.initialize();
    expect(controller.messages.last.content, '未完成的部分回答');

    await controller.send('新问题');

    expect(
      service.conversations.single.map((message) => message.content),
      ['旧问题', '新问题'],
    );
    expect(
      controller.messages.map((message) => message.content),
      contains('未完成的部分回答'),
    );
    controller.dispose();
  });

  test('controller cancels only its request-scoped streaming token', () async {
    const context = ChatContext(
      id: 'request-cancellation-test',
      title: '请求取消测试',
      systemPrompt: '回答问题。',
    );
    final service = _RequestScopedStreamingService();
    final controller = ChatConversationController(
      context: context,
      service: service,
    );

    final request = controller.send('开始生成');
    await service.started.future;
    controller.cancel();
    await request;

    expect(service.cancellation?.isCancelled, isTrue);
    expect(controller.requestStatus, ChatRequestStatus.cancelled);
    controller.dispose();
  });

  test('an unexpected save failure does not poison later queued writes',
      () async {
    const context = ChatContext(
      id: 'write-queue-recovery-test',
      title: '写队列恢复测试',
      systemPrompt: '回答问题。',
    );
    final repository = _UnexpectedFirstSaveRepository();
    final controller = ChatConversationController(
      context: context,
      service: _QueueChatAiService(['回答']),
      sessionRepository: repository,
    );

    await controller.send('问题');
    await controller.clear();

    expect(repository.saveCalls, 2);
    expect(repository.clearCalls, 1);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });

  test('send waits for a pending session load before mutating messages',
      () async {
    const context = ChatContext(
      id: 'pending-load-send-test',
      title: '加载期间发送测试',
      systemPrompt: '回答问题。',
    );
    final repository = _PendingChatSessionRepository();
    final service = _QueueChatAiService(['新回答']);
    final controller = ChatConversationController(
      context: context,
      service: service,
      sessionRepository: repository,
    );
    addTearDown(controller.dispose);

    final initialization = controller.initialize();
    final sending = controller.send('新问题');
    await Future<void>.delayed(Duration.zero);
    final requestedBeforeLoad = service.conversations.isNotEmpty;

    repository.completeLoad(const [
      ChatMessage(fromUser: true, content: '旧问题'),
      ChatMessage(fromUser: false, content: '旧回答'),
    ]);
    await Future.wait([initialization, sending]);

    expect(requestedBeforeLoad, isFalse);
    expect(
      controller.messages.map((message) => message.content),
      ['旧问题', '旧回答', '新问题', '新回答'],
    );
    expect(
      service.conversations.single.map((message) => message.content),
      ['旧问题', '旧回答', '新问题'],
    );
  });

  test('a pending settings load cannot overwrite a newer settings update',
      () async {
    const context = ChatContext(
      id: 'pending-settings-load-test',
      title: '设置加载竞态测试',
      systemPrompt: '回答问题。',
    );
    final repository = _PendingChatSessionSettingsRepository();
    final controller = ChatConversationController(
      context: context,
      service: _CapturingChatAiService(),
      settingsRepository: repository,
    );
    addTearDown(controller.dispose);

    final initialization = controller.initialize();
    await controller.updateSettings(
      const ChatSessionSettings(
        customSystemPrompt: '使用用户的新设置。',
        responseStyle: ChatResponseStyle.detailed,
      ),
    );
    repository.completeLoad(
      const ChatSessionSettings(
        customSystemPrompt: '这是迟到的旧设置。',
        responseStyle: ChatResponseStyle.concise,
      ),
    );
    await initialization;

    expect(controller.settings.customSystemPrompt, '使用用户的新设置。');
    expect(controller.settings.responseStyle, ChatResponseStyle.detailed);
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

class _RequestScopedStreamingService
    implements RequestScopedStreamingChatAiService {
  final Completer<void> started = Completer<void>();
  ChatRequestCancellation? cancellation;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '回答';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
    ChatRequestCancellation? cancellation,
  }) async* {
    this.cancellation = cancellation;
    if (!started.isCompleted) started.complete();
    yield const ChatStreamChunk(contentDelta: '部分回答');
    await cancellation!.whenCancelled;
    throw const ChatAiCancelledException();
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

class _UnexpectedFirstSaveRepository implements ChatSessionRepository {
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> clear(String contextId) async {
    clearCalls++;
  }

  @override
  Future<List<ChatMessage>> load(String contextId) async => const [];

  @override
  Future<List<ChatSessionSummary>> listSessions() async => const [];

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {
    saveCalls++;
    if (saveCalls == 1) throw StateError('unexpected save failure');
  }

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}

class _PendingChatSessionRepository implements ChatSessionRepository {
  final _load = Completer<List<ChatMessage>>();

  void completeLoad(List<ChatMessage> messages) => _load.complete(messages);

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<List<ChatMessage>> load(String contextId) => _load.future;

  @override
  Future<List<ChatSessionSummary>> listSessions() async => const [];

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}

class _PendingChatSessionSettingsRepository
    implements ChatSessionSettingsRepository {
  final _load = Completer<ChatSessionSettings>();

  void completeLoad(ChatSessionSettings settings) => _load.complete(settings);

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<ChatSessionSettings> load(String contextId) => _load.future;

  @override
  Future<void> save(
    String contextId,
    ChatSessionSettings settings,
  ) async {}
}
