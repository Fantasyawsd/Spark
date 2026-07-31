import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  test(
      'AI conversation retries the failed request without duplicating user text',
      () async {
    final service = _QueueAiService([
      const PaperAiException('网络失败'),
      '**重试成功**',
    ]);
    final controller = PaperAiConversationController(
      paper: demoPapers.first,
      service: service,
    );

    await controller.send('解释方法');
    expect(controller.error, '网络失败');
    expect(controller.messages, hasLength(1));

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
    final repository = InMemoryPaperAiSessionRepository();
    final first = PaperAiConversationController(
      paper: demoPapers.first,
      service: _QueueAiService(['回答']),
      sessionRepository: repository,
    );
    await first.send('问题');
    await Future<void>.delayed(Duration.zero);
    first.dispose();

    final restored = PaperAiConversationController(
      paper: demoPapers.first,
      service: _QueueAiService([]),
      sessionRepository: repository,
    );
    await restored.initialize();
    expect(restored.messages.map((message) => message.content), ['问题', '回答']);
    final sessions = await repository.listSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.paperId, demoPapers.first.id);
    expect(sessions.single.preview, '回答');

    await restored.clear();
    expect(restored.messages, isEmpty);
    expect(await repository.load(demoPapers.first.id), isEmpty);
    expect(await repository.listSessions(), isEmpty);
    restored.dispose();
  });

  test('AI conversation can stop an active request', () async {
    final service = _CancellableAiService();
    final controller = PaperAiConversationController(
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
    expect(controller.messages, hasLength(1));
    controller.dispose();
  });

  test('AI conversation keeps streamed reasoning separate from final answer',
      () async {
    final controller = PaperAiConversationController(
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
    final controller = PaperAiConversationController(
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
    final controller = PaperAiConversationController(
      paper: demoPapers.first,
      service: service,
    );

    controller.setReasoningEffort(PaperAiReasoningEffort.max);
    await controller.send('深入分析');

    expect(service.effort, PaperAiReasoningEffort.max);
    controller.dispose();
  });
}

class _ConfigurableAiService
    implements PaperAiService, ConfigurablePaperAiService {
  PaperAiReasoningEffort? effort;

  @override
  void setReasoningEffort(PaperAiReasoningEffort effort) {
    this.effort = effort;
  }

  @override
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async =>
      '回答';
}

class _QueueAiService implements PaperAiService {
  _QueueAiService(this.results);

  final List<Object> results;
  final List<List<PaperAiMessage>> conversations = [];

  @override
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async {
    conversations.add(List.from(conversation));
    final result = results.removeAt(0);
    if (result is PaperAiException) throw result;
    return result as String;
  }
}

class _CancellableAiService implements CancellablePaperAiService {
  Completer<String>? _completer;
  bool cancelled = false;

  @override
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) {
    _completer = Completer<String>();
    return _completer!.future;
  }

  @override
  void cancelActiveRequest() {
    cancelled = true;
    if (!(_completer?.isCompleted ?? true)) {
      _completer!.completeError(const PaperAiCancelledException());
    }
  }
}

class _StreamingAiService implements StreamingPaperAiService {
  const _StreamingAiService();

  @override
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async =>
      '**最终回答**';

  @override
  Stream<PaperAiStreamChunk> answerStream({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async* {
    yield const PaperAiStreamChunk(reasoningDelta: '先阅读摘要，');
    yield const PaperAiStreamChunk(reasoningDelta: '再核对结论。');
    yield const PaperAiStreamChunk(contentDelta: '**最终回答**');
  }
}

class _WebSearchAiService implements StreamingPaperAiService {
  int requests = 0;

  @override
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async =>
      '联网回答';

  @override
  Stream<PaperAiStreamChunk> answerStream({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async* {
    requests++;
    yield const PaperAiStreamChunk(searchStarted: true);
    yield const PaperAiStreamChunk(
      sources: [
        PaperAiSource(title: '论文主页', url: 'https://example.test/paper'),
      ],
    );
    yield const PaperAiStreamChunk(contentDelta: '联网回答');
  }
}
