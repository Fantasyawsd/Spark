import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/application/chat_conversation_request_state.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';

void main() {
  test('synchronous request completes and applies reasoning effort', () async {
    final service = _ConfigurableService('同步回答');
    final harness = _RequestHarness(service: service);
    harness.messages.add(const ChatMessage(fromUser: true, content: '问题'));
    harness.state.setReasoningEffort(ChatReasoningEffort.medium);

    await harness.state.requestAnswer();

    expect(harness.state.status, ChatRequestStatus.completed);
    expect(harness.state.sending, isFalse);
    expect(service.reasoningEffort, ChatReasoningEffort.medium);
    expect(service.conversation.single.content, '问题');
    expect(harness.messages.last.content, '同步回答');
    expect(harness.persistCount, 2);
  });

  test('web search request uses its service and merges stream chunks',
      () async {
    final base = _ConfigurableService('不应使用');
    final web = _StreamingService();
    final harness = _RequestHarness(service: base, webSearchService: web);
    harness.messages.add(const ChatMessage(fromUser: true, content: '搜索问题'));
    harness.state.setWebSearchEnabled(true);

    await harness.state.requestAnswer();

    expect(base.calls, 0);
    expect(web.calls, 1);
    expect(harness.state.webSearchEnabled, isTrue);
    expect(harness.state.searching, isFalse);
    expect(harness.messages.last.content, '最终回答');
    expect(harness.messages.last.reasoningContent, '推理过程');
    expect(harness.messages.last.sources.single.url, 'https://example.test');
  });

  test('request-scoped cancellation marks the active assistant', () async {
    final service = _RequestScopedService();
    final harness = _RequestHarness(service: service);
    harness.messages.add(const ChatMessage(fromUser: true, content: '开始'));

    final request = harness.state.requestAnswer();
    await service.started.future;
    harness.state.cancel();
    await request;

    expect(service.cancellation?.isCancelled, isTrue);
    expect(harness.state.status, ChatRequestStatus.cancelled);
    expect(harness.state.error, isNull);
    expect(harness.messages.last.content, '部分');
    expect(harness.messages.last.status, ChatMessageStatus.cancelled);
  });

  test('empty stream response becomes a retryable request failure', () async {
    final harness = _RequestHarness(service: _EmptyStreamingService());
    harness.messages.add(const ChatMessage(fromUser: true, content: '问题'));
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(
      events.add,
      harness.state.requestAnswer,
    );

    expect(harness.state.status, ChatRequestStatus.failed);
    expect(harness.state.canRetryRequestError, isTrue);
    expect(harness.state.error, 'AI 返回了空响应，请稍后重试。');
    expect(harness.messages.last.status, ChatMessageStatus.failed);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.chatConversationRequest],
    );
  });

  test('restored terminal messages map to the matching request status', () {
    final harness = _RequestHarness(service: _ConfigurableService('回答'));

    harness.messages.add(
      const ChatMessage(
        fromUser: false,
        content: '部分回答',
        status: ChatMessageStatus.cancelled,
      ),
    );
    harness.state.restoreFromMessages();
    expect(harness.state.status, ChatRequestStatus.cancelled);
    expect(harness.state.error, isNull);

    harness.messages
      ..clear()
      ..add(const ChatMessage(fromUser: true, content: '未回答问题'));
    harness.state.restoreFromMessages();
    expect(harness.state.status, ChatRequestStatus.failed);
    expect(harness.state.error, '上次回答未完成，请重新生成。');
  });
}

class _RequestHarness {
  _RequestHarness({
    required ChatAiService service,
    ChatAiService? webSearchService,
  }) {
    state = ChatConversationRequestState(
      service: service,
      webSearchService: webSearchService,
      messages: messages,
      effectiveContext: () => context,
      isDisposed: () => disposed,
      persist: () => persistCount++,
      notify: () => notifyCount++,
    );
  }

  static const context = ChatContext(
    id: 'request-state-test',
    title: '请求状态测试',
    systemPrompt: '回答测试问题。',
  );

  final List<ChatMessage> messages = [];
  late final ChatConversationRequestState state;
  bool disposed = false;
  int persistCount = 0;
  int notifyCount = 0;
}

class _ConfigurableService implements ChatAiService, ConfigurableChatAiService {
  _ConfigurableService(this.answerText);

  final String answerText;
  int calls = 0;
  ChatReasoningEffort? reasoningEffort;
  List<ChatMessage> conversation = const [];

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    calls++;
    this.conversation = conversation;
    return answerText;
  }

  @override
  void setReasoningEffort(ChatReasoningEffort effort) {
    reasoningEffort = effort;
  }
}

class _StreamingService implements StreamingChatAiService {
  int calls = 0;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '备用回答';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async* {
    calls++;
    yield const ChatStreamChunk(
      reasoningDelta: '推理过程',
      searchStarted: true,
      sources: [
        ChatSource(title: '来源', url: 'https://example.test'),
      ],
    );
    yield const ChatStreamChunk(
      contentDelta: '最终回答',
      searchFinished: true,
    );
  }
}

class _RequestScopedService implements RequestScopedStreamingChatAiService {
  final Completer<void> started = Completer<void>();
  ChatRequestCancellation? cancellation;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '备用回答';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
    ChatRequestCancellation? cancellation,
  }) async* {
    this.cancellation = cancellation;
    started.complete();
    yield const ChatStreamChunk(contentDelta: '部分');
    await cancellation!.whenCancelled;
    throw const ChatAiCancelledException();
  }
}

class _EmptyStreamingService implements StreamingChatAiService {
  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async* {}
}
