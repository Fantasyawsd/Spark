import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/app/spark_app.dart';
import 'package:spark/src/app/spark_dependencies.dart';
import 'package:spark/src/core/theme/theme_controller.dart';
import 'package:spark/src/features/chat/application/chat_conversation_coordinator.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_repository.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_chat_screen.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_discussion_view.dart';
import 'package:spark/src/features/local_data/domain/local_data_repository.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';

void main() {
  test('disposing the application coordinator cancels active replies',
      () async {
    const context = ChatContext(
      id: 'root-dispose-chat',
      title: '根组件销毁测试',
      systemPrompt: '回答问题。',
    );
    final service = _CancellationAwareChatAiService();
    final coordinator = ChatConversationCoordinator(
      sessionRepository: InMemoryChatSessionRepository(),
    );
    final conversation = coordinator.conversation(
      context: context,
      service: service,
    );

    final request = conversation.send('开始回答');
    await service.started.future;
    coordinator.dispose();
    await service.cancelled.future;
    await request;

    expect(service.cancellation?.isCancelled, isTrue);
  });

  testWidgets(
    'AI reply completes after leaving chat and is visible when returning',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _DelayedStreamingChatAiService();
      final repository = InMemoryChatSessionRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: SparkShell(
            aiService: service,
            aiSessionRepository: repository,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('paper-ai-input')),
        '离开页面后继续回答',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
      await _pumpUntil(tester, () => service.started.isCompleted);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('第一段'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('paper-ai-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-chat-home-title')), findsOneWidget);

      service.complete();
      await _pumpUntil(tester, () => service.finished.isCompleted);
      await _waitForCompletedReply(
        tester,
        repository,
        contextId: 'spark-main-ai-chat',
      );

      await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
      await tester.pumpAndSettle();

      expect(find.text('第一段完整回答'), findsOneWidget);
    },
  );

  testWidgets(
    'paper reply completes after leaving full-screen chat',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _DelayedStreamingChatAiService();
      final repository = InMemoryChatSessionRepository();
      final paper = const ArxivSeedRepository().getAll().first;
      await repository.save(paper.id, const [
        ChatMessage(fromUser: true, content: '已有问题'),
        ChatMessage(fromUser: false, content: '已有回答'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: SparkShell(
            aiService: service,
            aiSessionRepository: repository,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('ai-session-${paper.id}')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('paper-ai-input')),
        '论文页面外继续回答',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
      await _pumpUntil(tester, () => service.started.isCompleted);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('第一段'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('paper-ai-back')));
      await tester.pumpAndSettle();
      service.complete();
      await _pumpUntil(tester, () => service.finished.isCompleted);
      await _waitForCompletedReply(
        tester,
        repository,
        contextId: paper.id,
      );

      await tester.tap(find.byKey(ValueKey('ai-session-${paper.id}')));
      await tester.pumpAndSettle();

      expect(find.text('第一段完整回答'), findsOneWidget);
    },
  );

  testWidgets(
    'paper discussion and full-screen chat share an in-flight reply',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const chatContext = ChatContext(
        id: 'shared-paper-chat',
        title: '共享论文会话',
        systemPrompt: '回答论文问题。',
      );
      final service = _DelayedStreamingChatAiService();
      final repository = InMemoryChatSessionRepository();
      final coordinator = ChatConversationCoordinator(
        sessionRepository: repository,
      );
      addTearDown(coordinator.dispose);
      final conversation = coordinator.conversation(
        context: chatContext,
        service: service,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaperAiDiscussionView(
              chatContext: chatContext,
              aiService: service,
              sessionRepository: repository,
              conversationController: conversation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('paper-ai-input')),
        '从内嵌讨论发起',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
      await _pumpUntil(tester, () => service.started.isCompleted);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('第一段'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: PaperAiChatScreen(
            chatContext: chatContext,
            aiService: service,
            sessionRepository: repository,
            conversationController: coordinator.conversation(
              context: chatContext,
              service: service,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('第一段'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('paper-ai-composer-stop')),
        findsOneWidget,
      );

      service.complete();
      await _pumpUntil(tester, () => service.finished.isCompleted);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('第一段完整回答'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting a session stops its background reply without restoring data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _DelayedStreamingChatAiService();
      final repository = InMemoryChatSessionRepository();
      final paper = const ArxivSeedRepository().getAll().first;
      await repository.save(paper.id, const [
        ChatMessage(fromUser: true, content: '准备删除的问题'),
        ChatMessage(fromUser: false, content: '准备删除的回答'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: SparkShell(
            aiService: service,
            aiSessionRepository: repository,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
      await tester.pumpAndSettle();
      final sessionCard = find.byKey(ValueKey('ai-session-${paper.id}'));
      await tester.tap(sessionCard);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('paper-ai-input')),
        '这条后台回复不应复活会话',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
      await _pumpUntil(tester, () => service.started.isCompleted);
      await tester.tap(find.byKey(const ValueKey('paper-ai-back')));
      await tester.pumpAndSettle();

      await tester.drag(sessionCard, const Offset(-180, 0));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('ai-session-delete-${paper.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-delete-ai-session')),
      );
      await tester.pumpAndSettle();
      expect(await repository.listSessions(), isEmpty);

      service.complete();
      await _pumpUntil(tester, () => service.finished.isCompleted);
      await tester.pump(const Duration(milliseconds: 40));

      expect(await repository.listSessions(), isEmpty);
    },
  );

  testWidgets(
    'clearing ChatPaper data stops background replies before deleting storage',
    (tester) async {
      ThemeController.instance.debugResetForTesting();
      addTearDown(ThemeController.instance.debugResetForTesting);
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _DelayedStreamingChatAiService();
      final repository = InMemoryChatSessionRepository();
      final localDataRepository = _ChatClearingLocalDataRepository(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: SparkShell(
            dependencies: SparkDependencies.preview(
              aiService: service,
              aiSessionRepository: repository,
              localDataRepository: localDataRepository,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('paper-ai-input')),
        '清除后不能恢复的回复',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
      await _pumpUntil(tester, () => service.started.isCompleted);
      await tester.tap(find.byKey(const ValueKey('paper-ai-back')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-local-data')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('profile-local-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('local-data-clear-chats')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('local-data-confirm')));
      await _pumpUntil(tester, () => localDataRepository.chatsCleared);
      await tester.pump(const Duration(milliseconds: 400));
      expect(await repository.listSessions(), isEmpty);

      service.complete();
      await _pumpUntil(tester, () => service.finished.isCompleted);
      await tester.pump(const Duration(milliseconds: 40));

      expect(await repository.listSessions(), isEmpty);
    },
  );

  testWidgets(
    'a reply that fails while away is retryable when returning',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _FailThenRecoverChatAiService();
      final repository = InMemoryChatSessionRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: SparkShell(
            aiService: service,
            aiSessionRepository: repository,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('paper-ai-input')),
        '离开期间失败',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
      await _pumpUntil(tester, () => service.started.isCompleted);
      await tester.tap(find.byKey(const ValueKey('paper-ai-back')));
      await tester.pumpAndSettle();

      service.fail();
      await _pumpUntil(tester, () => service.firstFinished.isCompleted);
      await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
      await tester.pumpAndSettle();

      expect(find.text('离开期间请求失败'), findsOneWidget);
      await tester.tap(find.byTooltip('重新生成'));
      await tester.pumpAndSettle();
      expect(find.text('恢复后的完整回答'), findsOneWidget);
    },
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(condition(), isTrue);
}

Future<void> _waitForCompletedReply(
  WidgetTester tester,
  InMemoryChatSessionRepository repository, {
  required String contextId,
}) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final messages = await repository.load(contextId);
    if (messages.any((message) => message.content == '第一段完整回答')) return;
    await tester.pump(const Duration(milliseconds: 10));
  }
}

class _DelayedStreamingChatAiService
    implements RequestScopedStreamingChatAiService {
  final Completer<void> started = Completer<void>();
  final Completer<void> _complete = Completer<void>();
  final Completer<void> finished = Completer<void>();

  void complete() => _complete.complete();

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '不会走非流式路径';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
    ChatRequestCancellation? cancellation,
  }) async* {
    try {
      if (!started.isCompleted) started.complete();
      yield const ChatStreamChunk(contentDelta: '第一段');
      await _complete.future;
      if (cancellation?.isCancelled ?? false) {
        throw const ChatAiCancelledException();
      }
      yield const ChatStreamChunk(contentDelta: '完整回答');
    } finally {
      if (!finished.isCompleted) finished.complete();
    }
  }
}

class _ChatClearingLocalDataRepository implements LocalDataRepository {
  _ChatClearingLocalDataRepository(this.chatRepository);

  final InMemoryChatSessionRepository chatRepository;
  bool _chatsCleared = false;
  bool get chatsCleared => _chatsCleared;

  @override
  Future<void> clearChats() async {
    await chatRepository.clear('spark-main-ai-chat');
    _chatsCleared = true;
  }

  @override
  Future<void> clearPaperCache() async {}

  @override
  Future<LocalDataUsage> inspect() async => LocalDataUsage(
        paperCacheBytes: 0,
        chatBytes: _chatsCleared ? 0 : 1024,
        businessDataBytes: 0,
      );

  @override
  Future<void> resetAllBusinessData() => clearChats();
}

class _CancellationAwareChatAiService
    implements RequestScopedStreamingChatAiService {
  final Completer<void> started = Completer<void>();
  final Completer<void> cancelled = Completer<void>();
  ChatRequestCancellation? cancellation;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '不会走非流式路径';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
    ChatRequestCancellation? cancellation,
  }) async* {
    this.cancellation = cancellation;
    started.complete();
    yield const ChatStreamChunk(contentDelta: '部分回答');
    await cancellation!.whenCancelled;
    cancelled.complete();
    throw const ChatAiCancelledException();
  }
}

class _FailThenRecoverChatAiService
    implements RequestScopedStreamingChatAiService {
  final Completer<void> started = Completer<void>();
  final Completer<void> _fail = Completer<void>();
  final Completer<void> firstFinished = Completer<void>();
  int _requests = 0;

  void fail() => _fail.complete();

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '不会走非流式路径';

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
    ChatRequestCancellation? cancellation,
  }) async* {
    _requests++;
    if (_requests == 1) {
      try {
        started.complete();
        yield const ChatStreamChunk(contentDelta: '部分回答');
        await _fail.future;
        throw const ChatAiException('离开期间请求失败');
      } finally {
        firstFinished.complete();
      }
    }
    yield const ChatStreamChunk(contentDelta: '恢复后的完整回答');
  }
}
