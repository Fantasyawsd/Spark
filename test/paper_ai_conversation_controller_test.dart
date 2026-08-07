import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/chat/application/chat_conversation_controller.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_repository.dart';
import 'package:spark/src/features/papers/application/paper_chat_context.dart';
import 'package:spark/src/features/papers/data/demo_paper_repository.dart';

void main() {
  test(
      'AI conversation retries the failed request without duplicating user text',
      () async {
    final service = _QueueAiService([
      const ChatAiException('网络失败'),
      '**重试成功**',
    ]);
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: service,
    );

    await controller.send('解释方法');
    expect(controller.error, '网络失败');
    expect(controller.messages, hasLength(2));
    expect(controller.messages.last.status, ChatMessageStatus.failed);
    expect(controller.canRetryRequestError, isTrue);

    await controller.retry();
    expect(controller.error, isNull);
    expect(controller.messages, hasLength(2));
    expect(controller.messages.last.content, '**重试成功**');
    expect(service.conversations.last.where((message) => message.fromUser),
        hasLength(1));
    controller.dispose();
  });

  test('AI conversation restores and clears a paper scoped local session',
      () async {
    final repository = InMemoryChatSessionRepository();
    final first = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService(['回答']),
      sessionRepository: repository,
    );
    await first.send('问题');
    await Future<void>.delayed(Duration.zero);
    first.dispose();

    final restored = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService([]),
      sessionRepository: repository,
    );
    await restored.initialize();
    expect(restored.messages.map((message) => message.content), ['问题', '回答']);
    final sessions = await repository.listSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.contextId, demoPapers.first.id);
    expect(sessions.single.preview, '回答');
    expect(sessions.single.pinned, isFalse);

    await repository.setPinned(demoPapers.first.id, true);
    expect((await repository.listSessions()).single.pinned, isTrue);

    await restored.clear();
    expect(restored.messages, isEmpty);
    expect(await repository.load(demoPapers.first.id), isEmpty);
    expect(await repository.listSessions(), isEmpty);
    restored.dispose();
  });

  test('clearing a conversation waits for queued saves before deletion',
      () async {
    final repository = _DelayedSaveAiSessionRepository();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService(['回答']),
      sessionRepository: repository,
    );

    await controller.send('问题');
    await repository.firstSaveStarted.future;

    final clear = controller.clear();
    await Future<void>.delayed(Duration.zero);
    expect(repository.clearCalls, 0);

    repository.releaseSaves.complete();
    await clear;

    expect(repository.clearCalls, 1);
    expect(await repository.load(demoPapers.first.id), isEmpty);
    controller.dispose();
  });

  test('AI conversation can stop an active request', () async {
    final service = _CancellableAiService();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: service,
    );

    final request = controller.send('一个较长的问题');
    expect(controller.sending, isTrue);
    controller.cancel();
    await request;

    expect(service.cancelled, isTrue);
    expect(controller.sending, isFalse);
    expect(controller.error, isNull);
    expect(controller.messages, hasLength(2));
    expect(controller.messages.last.status, ChatMessageStatus.cancelled);
    expect(controller.requestStatus, ChatRequestStatus.cancelled);
    expect(controller.canRetry, isTrue);
    controller.dispose();
  });

  test('cancel before the first token restores as cancelled', () async {
    final repository = InMemoryChatSessionRepository();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: _CancellableAiService(),
      sessionRepository: repository,
    );

    final request = controller.send('问题');
    controller.cancel();
    await request;
    await Future<void>.delayed(Duration.zero);

    final restored = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService(['回答']),
      sessionRepository: repository,
    );
    await restored.initialize();

    expect(restored.requestStatus, ChatRequestStatus.cancelled);
    expect(restored.messages.last.status, ChatMessageStatus.cancelled);
    await restored.retry();
    expect(restored.messages.last.content, '回答');
    controller.dispose();
    restored.dispose();
  });

  test('failure before the first token restores as failed', () async {
    final repository = InMemoryChatSessionRepository();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService([const ChatAiException('网络失败')]),
      sessionRepository: repository,
    );

    await controller.send('问题');
    await Future<void>.delayed(Duration.zero);

    final restored = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService(['回答']),
      sessionRepository: repository,
    );
    await restored.initialize();

    expect(restored.requestStatus, ChatRequestStatus.failed);
    expect(restored.error, '上次回答未完成，请重新生成。');
    expect(restored.canRetryRequestError, isTrue);
    await restored.retry();
    expect(restored.messages.last.content, '回答');
    controller.dispose();
    restored.dispose();
  });

  test('a new question omits an empty terminal marker from AI context',
      () async {
    final repository = InMemoryChatSessionRepository();
    await repository.save(demoPapers.first.id, const [
      ChatMessage(fromUser: true, content: '旧问题'),
      ChatMessage(
        fromUser: false,
        content: '',
        status: ChatMessageStatus.cancelled,
      ),
    ]);
    final service = _QueueAiService(['新回答']);
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: service,
      sessionRepository: repository,
    );
    await controller.initialize();

    await controller.send('新问题');

    final conversation = service.conversations.single;
    expect(
      conversation.where(
        (message) =>
            !message.fromUser &&
            message.content.isEmpty &&
            message.reasoningContent.isEmpty &&
            message.sources.isEmpty,
      ),
      isEmpty,
    );
    expect(conversation.map((message) => message.content), ['旧问题', '新问题']);
    controller.dispose();
  });

  test('cancelled AI conversation restores its regenerate state', () async {
    final repository = InMemoryChatSessionRepository();
    final service = _RegeneratingStreamingAiService();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: service,
      sessionRepository: repository,
    );

    final request = controller.send('分析论文');
    await service.firstChunkSent.future;
    await Future<void>.delayed(Duration.zero);
    controller.cancel();
    await request;
    await Future<void>.delayed(Duration.zero);

    final restored = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService(['完整回答']),
      sessionRepository: repository,
    );
    await restored.initialize();

    expect(restored.requestStatus, ChatRequestStatus.cancelled);
    expect(restored.canRetry, isTrue);
    expect(restored.messages.last.status, ChatMessageStatus.cancelled);

    await restored.retry();
    expect(restored.messages, hasLength(2));
    expect(restored.messages.last.content, '完整回答');
    controller.dispose();
    restored.dispose();
  });

  test('an obsolete persistence failure does not pollute a newer save',
      () async {
    final repository = _ObsoleteFailureAiSessionRepository();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService(['回答']),
      sessionRepository: repository,
    );

    await controller.send('问题');
    await repository.firstSaveStarted.future;
    repository.releaseFirstSave.complete();
    await repository.latestSaveCompleted.future;

    expect(controller.requestStatus, ChatRequestStatus.completed);
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('cancel persistence failure does not masquerade as request retry',
      () async {
    final repository = _CancelSaveFailureAiSessionRepository();
    final service = _CancellableAiService();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: service,
      sessionRepository: repository,
    );

    final request = controller.send('问题');
    controller.cancel();
    await request;
    await repository.cancelSaveFailed.future;
    await Future<void>.delayed(Duration.zero);

    expect(controller.requestStatus, ChatRequestStatus.cancelled);
    expect(controller.error, '无法保存取消状态');
    expect(controller.canRetry, isTrue);
    expect(controller.canRetryRequestError, isFalse);
    controller.dispose();
  });

  test('clear persistence failure does not expose AI regenerate', () async {
    final repository = _ClearFailureAiSessionRepository();
    await repository.save(
      demoPapers.first.id,
      const [ChatMessage(fromUser: true, content: '问题')],
    );
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService([]),
      sessionRepository: repository,
    );
    await controller.initialize();

    await controller.clear();

    expect(controller.requestStatus, ChatRequestStatus.idle);
    expect(controller.canRetry, isFalse);
    expect(controller.error, '无法清空 AI 对话记录。');
    controller.dispose();
  });

  test(
      'AI conversation preserves a partial stream and replaces it when regenerated',
      () async {
    final service = _RegeneratingStreamingAiService();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: service,
    );

    final request = controller.send('分析论文');
    await service.firstChunkSent.future;
    await Future<void>.delayed(Duration.zero);

    controller.cancel();
    await request;

    expect(controller.requestStatus, ChatRequestStatus.cancelled);
    expect(controller.canRetry, isTrue);
    expect(controller.messages, hasLength(2));
    expect(controller.messages.last.content, '部分回答');

    await controller.retry();

    expect(controller.requestStatus, ChatRequestStatus.completed);
    expect(controller.canRetry, isFalse);
    expect(controller.messages, hasLength(2));
    expect(controller.messages.last.content, '完整回答');

    await controller.clear();
    expect(controller.requestStatus, ChatRequestStatus.idle);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });

  test('AI conversation keeps streamed reasoning separate from final answer',
      () async {
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: const _StreamingAiService(),
    );

    await controller.send('分析论文');

    expect(controller.messages, hasLength(2));
    expect(controller.messages.last.reasoningContent, '先阅读摘要，再核对结论。');
    expect(controller.messages.last.content, '**最终回答**');
    controller.dispose();
  });

  test('AI conversation can switch to web search and retain sources', () async {
    final webService = _WebSearchAiService();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: _QueueAiService(['普通回答']),
      webSearchService: webService,
    );

    controller.setWebSearchEnabled(true);
    await controller.send('搜索后续工作');

    expect(webService.requests, 1);
    expect(controller.messages.last.content, '联网回答');
    expect(controller.messages.last.sources.single.title, '论文主页');
    controller.dispose();
  });

  test('AI conversation applies the selected reasoning effort', () async {
    final service = _ConfigurableAiService();
    final controller = _paperConversationController(
      paper: demoPapers.first,
      service: service,
    );

    controller.setReasoningEffort(ChatReasoningEffort.max);
    await controller.send('深入分析');

    expect(service.effort, ChatReasoningEffort.max);
    controller.dispose();
  });
}

ChatConversationController _paperConversationController({
  required Paper paper,
  List<String> generatedKeywords = const [],
  required ChatAiService service,
  ChatAiService? webSearchService,
  ChatSessionRepository? sessionRepository,
}) {
  return ChatConversationController(
    context: PaperChatContext.fromPaper(
      paper,
      generatedKeywords: generatedKeywords,
    ),
    service: service,
    webSearchService: webSearchService,
    sessionRepository: sessionRepository,
  );
}

class _ConfigurableAiService
    implements ChatAiService, ConfigurableChatAiService {
  ChatReasoningEffort? effort;

  @override
  void setReasoningEffort(ChatReasoningEffort effort) {
    this.effort = effort;
  }

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '回答';
}

class _QueueAiService implements ChatAiService {
  _QueueAiService(this.results);

  final List<Object> results;
  final List<List<ChatMessage>> conversations = [];

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    conversations.add(List.from(conversation));
    final result = results.removeAt(0);
    if (result is ChatAiException) throw result;
    return result as String;
  }
}

class _CancellableAiService implements CancellableChatAiService {
  Completer<String>? _completer;
  bool cancelled = false;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) {
    _completer = Completer<String>();
    return _completer!.future;
  }

  @override
  void cancelActiveRequest() {
    cancelled = true;
    if (!(_completer?.isCompleted ?? true)) {
      _completer!.completeError(const ChatAiCancelledException());
    }
  }
}

class _DelayedSaveAiSessionRepository extends InMemoryChatSessionRepository {
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> releaseSaves = Completer<void>();
  int clearCalls = 0;

  @override
  Future<void> save(
    String contextId,
    List<ChatMessage> messages,
  ) async {
    if (!firstSaveStarted.isCompleted) firstSaveStarted.complete();
    await releaseSaves.future;
    await super.save(contextId, messages);
  }

  @override
  Future<void> clear(String contextId) async {
    clearCalls++;
    await super.clear(contextId);
  }
}

class _ObsoleteFailureAiSessionRepository
    extends InMemoryChatSessionRepository {
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> releaseFirstSave = Completer<void>();
  final Completer<void> latestSaveCompleted = Completer<void>();
  var _saveCalls = 0;

  @override
  Future<void> save(
    String contextId,
    List<ChatMessage> messages,
  ) async {
    _saveCalls++;
    if (_saveCalls == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
      throw const ChatSessionPersistenceException('旧写入失败');
    }
    await super.save(contextId, messages);
    if (!latestSaveCompleted.isCompleted) latestSaveCompleted.complete();
  }
}

class _ClearFailureAiSessionRepository extends InMemoryChatSessionRepository {
  @override
  Future<void> clear(String contextId) async {
    throw const ChatSessionPersistenceException('无法清空 AI 对话记录。');
  }
}

class _CancelSaveFailureAiSessionRepository
    extends InMemoryChatSessionRepository {
  final Completer<void> cancelSaveFailed = Completer<void>();
  var _saveCalls = 0;

  @override
  Future<void> save(
    String contextId,
    List<ChatMessage> messages,
  ) async {
    _saveCalls++;
    if (_saveCalls == 2) {
      if (!cancelSaveFailed.isCompleted) cancelSaveFailed.complete();
      throw const ChatSessionPersistenceException('无法保存取消状态');
    }
    await super.save(contextId, messages);
  }
}

class _StreamingAiService implements StreamingChatAiService {
  const _StreamingAiService();

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '**最终回答**';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async* {
    yield const ChatStreamChunk(reasoningDelta: '先阅读摘要，');
    yield const ChatStreamChunk(reasoningDelta: '再核对结论。');
    yield const ChatStreamChunk(contentDelta: '**最终回答**');
  }
}

class _RegeneratingStreamingAiService
    implements StreamingChatAiService, CancellableChatAiService {
  final Completer<void> firstChunkSent = Completer<void>();
  Completer<void>? _cancelled;
  int _requests = 0;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '完整回答';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async* {
    _requests++;
    if (_requests > 1) {
      yield const ChatStreamChunk(contentDelta: '完整回答');
      return;
    }

    _cancelled = Completer<void>();
    yield const ChatStreamChunk(contentDelta: '部分回答');
    if (!firstChunkSent.isCompleted) firstChunkSent.complete();
    await _cancelled!.future;
    throw const ChatAiCancelledException();
  }

  @override
  void cancelActiveRequest() {
    if (!(_cancelled?.isCompleted ?? true)) _cancelled!.complete();
  }
}

class _WebSearchAiService implements StreamingChatAiService {
  int requests = 0;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '联网回答';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async* {
    requests++;
    yield const ChatStreamChunk(searchStarted: true);
    yield const ChatStreamChunk(
      sources: [
        ChatSource(title: '论文主页', url: 'https://example.test/paper'),
      ],
    );
    yield const ChatStreamChunk(contentDelta: '联网回答');
  }
}
