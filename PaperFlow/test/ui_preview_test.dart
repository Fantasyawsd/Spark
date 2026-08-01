import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/features/chat/domain/chat_context.dart';
import 'package:paperflow/src/features/papers/presentation/widgets/paper_reader_view.dart';

void main() {
  testWidgets('paper title copies on tap while body remains selectable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    const title =
        'Corruption Robust Offline Reinforcement Learning with Human Feedback';
    await tester.tap(find.byKey(const ValueKey('paper-title-2402.06734')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('论文题目已复制'), findsNothing);
    expect(copiedText, title);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('paper metadata exposes the primary reading path',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final linkService = _FakePaperLinkService();

    await tester.pumpWidget(
      PaperFlowApp(
        showSplash: false,
        linkService: linkService,
      ),
    );
    await tester.pump();

    expect(find.text('关注作者'), findsOneWidget);
    expect(find.textContaining('· arXiv'), findsNothing);
    expect(find.textContaining('被引 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-open-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-entry')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PaperActionBar),
        matching: find.text('0'),
      ),
      findsNWidgets(4),
    );
    expect(
      find.descendant(
        of: find.byType(PaperActionBar),
        matching: find.text('AI'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('paper-open-link')));
    await tester.pump();
    expect(linkService.opened.single.toString(), contains('/pdf/2402.06734'));
  });

  testWidgets('paper tabs animate content and actions keep shared state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const PaperFlowApp(
        showSplash: false,
        translationServiceFactory: _FakePaperTranslationServiceFactory(),
      ),
    );
    await tester.pump();

    final pagesSize = tester.getSize(
      find.byKey(const ValueKey('paper-tab-pages')).first,
    );
    await tester.tap(find.text('中文解读').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byKey(const ValueKey('paper-tab-pages')).first),
      pagesSize,
    );
    await tester.pumpAndSettle();
    expect(find.text('DeepSeek 中文翻译'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_rounded), findsWidgets);
  });

  testWidgets('each paper in the vertical feed starts on the original tab',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    final firstReader = find.byType(PaperReaderView).first;
    await tester.tap(
      find.descendant(
        of: firstReader,
        matching: find.text('相关论文'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: firstReader,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is PaperFlowSegmentedControl && widget.selectedIndex == 2,
        ),
      ),
      findsOneWidget,
    );

    final feed = tester.widget<PageView>(
      find.byKey(const ValueKey('paper-feed')),
    );
    unawaited(
      feed.controller!.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<PaperFlowSegmentedControl>(
            find.byType(PaperFlowSegmentedControl).hitTestable(),
          )
          .selectedIndex,
      0,
    );

    unawaited(
      feed.controller!.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PaperFlowSegmentedControl>(
            find.byType(PaperFlowSegmentedControl).hitTestable(),
          )
          .selectedIndex,
      0,
    );
  });

  testWidgets('related paper opens a fullscreen detail and returns to feed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();
    await tester.tap(find.text('相关论文').first);
    await tester.pumpAndSettle();

    final related = find.byKey(
      const ValueKey('related-paper-2404.01356'),
    );
    expect(related, findsOneWidget);
    await tester.tap(related);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('paper-title-2404.01356')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('paper-detail-2404.01356')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('papers-header')), findsNothing);
    expect(find.byKey(const ValueKey('bottom-nav-0')), findsNothing);

    await tester.tap(find.text('相关论文').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('related-paper-2402.06734')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('paper-detail-2402.06734')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('paper-detail-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('paper-detail-2404.01356')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('paper-detail-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('paper-title-2402.06734')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('papers-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-0')), findsOneWidget);
  });

  testWidgets('saved paper detail returns to profile without moving the feed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final interactions = InMemoryPaperInteractionRepository(
      PaperInteractionSnapshot(savedPaperIds: {'2404.01356'}),
    );

    await tester.pumpWidget(
      PaperFlowApp(
        showSplash: false,
        interactionRepository: interactions,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();

    final savedPaper = find.byKey(
      const ValueKey('profile-saved-paper-2404.01356'),
    );
    expect(savedPaper, findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(savedPaper);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('paper-title-2404.01356')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('paper-detail-2404.01356')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('papers-header')), findsNothing);
    expect(find.byKey(const ValueKey('bottom-nav-2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('paper-detail-back')));
    await tester.pumpAndSettle();
    expect(savedPaper, findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('paper-title-2402.06734')),
      findsOneWidget,
    );
  });

  testWidgets('favorite tap uses default group and long press selects groups',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperInteractionRepository();
    final paper = const ArxivSeedRepository().getAll().first;

    await tester.pumpWidget(
      PaperFlowApp(
        showSplash: false,
        interactionRepository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-action-save')).first);
    await tester.pumpAndSettle();
    expect(
      (await repository.load()).favoritePaperIdsByGroup[defaultFavoriteGroupId],
      contains(paper.id),
    );

    await tester.longPress(
      find.byKey(const ValueKey('paper-action-save')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('收藏到分组'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('favorite-group-default')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('create-favorite-group')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('favorite-group-name-input')),
      '重点阅读',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-create-favorite-group')),
    );
    await tester.pumpAndSettle();

    final snapshot = await repository.load();
    final customGroup = snapshot.favoriteGroups.singleWhere(
      (group) => group.name == '重点阅读',
    );
    expect(
      snapshot.favoritePaperIdsByGroup[customGroup.id],
      contains(paper.id),
    );

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('profile-favorite-group-${customGroup.id}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('profile-saved-paper-${paper.id}')),
      findsOneWidget,
    );
  });

  testWidgets('read later and reading history appear in profile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperReadingRepository();

    await tester.pumpWidget(
      PaperFlowApp(
        showSplash: false,
        readingRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    final paper = const ArxivSeedRepository().getAll().first;

    await tester.tap(find.byKey(const ValueKey('paper-action-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入稍后阅读'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('profile-read-later-paper-${paper.id}')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(ValueKey('profile-read-later-paper-${paper.id}')),
    );
    await tester.drag(
      find.byKey(const ValueKey('profile-scroll')),
      const Offset(0, -140),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('profile-read-later-paper-${paper.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('paper-title-${paper.id}')), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('profile-history-paper-${paper.id}')),
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(ValueKey('profile-history-paper-${paper.id}')),
      findsOneWidget,
    );
  });

  testWidgets('long Chinese interpretation can open the full reader',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PaperFlowApp(
        showSplash: false,
        translationServiceFactory: _FakePaperTranslationServiceFactory(
          content: List.filled(160, '这是中文解读正文').join(' '),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('中文解读').first);
    await tester.pumpAndSettle();

    expect(find.text('展开全文'), findsOneWidget);
    await tester.tap(find.text('展开全文'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-full-reader')), findsOneWidget);
    expect(find.text('中文解读'), findsOneWidget);
  });

  testWidgets('abstract expansion appears only when text exceeds its viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final longController = PaperController(
      _TestPaperRepository(_testPaper(List.filled(120, 'LoRA').join(' '))),
    );
    final longComments = PaperCommentController();
    addTearDown(longController.dispose);
    addTearDown(longComments.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PapersScreen(
            readingController: PaperReadingController(),
            feedController: longController.feed,
            interactionController: longController.interactions,
            commentController: longComments,
            aiService: const _FakePaperAiService(),
            translationServiceFactory:
                const _FakePaperTranslationServiceFactory(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('展开全文'), findsOneWidget);
    await tester.tap(find.text('展开全文'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-full-reader')), findsOneWidget);
    expect(find.text('原文摘要'), findsOneWidget);

    final shortController = PaperController(
      _TestPaperRepository(_testPaper('A short abstract.')),
    );
    final shortComments = PaperCommentController();
    addTearDown(shortController.dispose);
    addTearDown(shortComments.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PapersScreen(
            readingController: PaperReadingController(),
            feedController: shortController.feed,
            interactionController: shortController.interactions,
            commentController: shortComments,
            aiService: const _FakePaperAiService(),
            translationServiceFactory:
                const _FakePaperTranslationServiceFactory(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('展开全文'), findsNothing);
  });

  testWidgets('paper layout switches between fullscreen and grid',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey('paper-feed'))).height,
        greaterThan(700));
    expect(find.textContaining('被引 0'), findsOneWidget);
    expect(find.text('中文解读'), findsWidgets);

    await tester.tap(find.text('论文 ⇄'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-grid')), findsOneWidget);
    expect(find.text('‹ 返回'), findsOneWidget);

    await tester.tap(find.textContaining('Perturbation Effects on Robustness'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-feed')), findsOneWidget);
    expect(find.textContaining('Perturbation Effects on Robustness'),
        findsOneWidget);
    expect(find.text('论文 ⇄'), findsOneWidget);
  });

  testWidgets('paper feed is clipped below the fixed header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('papers-header'));
    final viewport = find.byKey(const ValueKey('paper-feed-viewport'));
    final headerBottom = tester.getBottomLeft(header).dy;
    final viewportTop = tester.getTopLeft(viewport).dy;

    expect(viewportTop, closeTo(headerBottom, 0.1));

    await tester.drag(
      find.byKey(const ValueKey('paper-feed')),
      const Offset(0, -260),
    );
    await tester.pump();

    expect(tester.getTopLeft(viewport).dy, closeTo(headerBottom, 0.1));
  });

  testWidgets('comments sheet switches to AI conversation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('评论 0'), findsOneWidget);
    expect(find.text('AI 解析'), findsOneWidget);
    expect(find.text('还没有评论，来发表第一条看法吧'), findsOneWidget);

    final halfHeight = tester
        .getSize(find.byKey(const ValueKey('paper-comments-sheet')))
        .height;
    final contentSize =
        tester.getSize(find.byKey(const ValueKey('paper-sheet-pages')));
    expect(halfHeight, inInclusiveRange(350, 450));

    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    final fullHeight = tester
        .getSize(find.byKey(const ValueKey('paper-comments-sheet')))
        .height;
    expect(fullHeight, greaterThan(700));

    await tester.tap(find.byTooltip('恢复半屏'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI 解析'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('paper-sheet-pages'))),
      contentSize,
    );
    expect(find.text('解释核心方法'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-input')), findsOneWidget);
  });

  testWidgets('comments and local AI messages complete their send flow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final comments = PaperCommentController();
    addTearDown(comments.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPaperCommentsSheet(
                context,
                demoPapers.first,
                aiService: const _FakePaperAiService(),
                commentController: comments,
              ),
              child: const Text('打开评论'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开评论'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '这是一条本地评论');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('这是一条本地评论'), findsOneWidget);

    await tester.tap(find.text('AI 解析'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '总结实验效果');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.textContaining('DeepSeek Markdown'), findsOneWidget);
  });

  testWidgets('failed comment restores only the comment composer',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledCommentWidgetRepository();
    final comments = PaperCommentController(repository: repository);
    addTearDown(comments.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPaperCommentsSheet(
                context,
                demoPapers.first,
                aiService: const _FakePaperAiService(),
                commentController: comments,
              ),
              child: const Text('打开失败评论'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开失败评论'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paper-comment-input')),
      '需要重试的评论',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-comment-send')));
    await tester.pump();

    await tester.tap(find.text('AI 解析'));
    await tester.pumpAndSettle();
    repository.failSave();
    await tester.pumpAndSettle();

    final aiInput = tester.widget<TextField>(
      find.byKey(const ValueKey('paper-ai-input')),
    );
    expect(aiInput.controller!.text, isEmpty);

    await tester.tap(find.textContaining('评论 '));
    await tester.pumpAndSettle();
    expect(find.text('需要重试的评论'), findsOneWidget);
  });

  testWidgets('interaction failure is reported after papers reactivate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledInteractionWidgetRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PaperFlowShell(
          interactionRepository: repository,
          aiService: const _FakePaperAiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('点赞').first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    repository.failSave();
    await tester.pump();
    expect(find.text('保存互动失败'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('保存互动失败'), findsOneWidget);
  });

  testWidgets('paper action count updates after a local comment is sent',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperCommentRepository();

    await tester.pumpWidget(
      PaperFlowApp(
        showSplash: false,
        commentRepository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('paper-action-comment'));
    expect(
        find.descendant(of: action, matching: find.text('0')), findsOneWidget);

    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '计数同步评论');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const ValueKey('paper-comments-sheet'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(
        find.descendant(of: action, matching: find.text('1')), findsOneWidget);
  });

  testWidgets('comments, replies and likes persist per paper', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperCommentRepository();
    final comments = PaperCommentController(repository: repository);
    addTearDown(comments.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPaperCommentsSheet(
                context,
                demoPapers.first,
                aiService: const _FakePaperAiService(),
                commentController: comments,
              ),
              child: const Text('打开持久评论'),
            ),
          ),
        ),
      ),
    );

    Future<void> openSheet() async {
      await tester.tap(find.text('打开持久评论'));
      await tester.pumpAndSettle();
    }

    await openSheet();
    await tester.enterText(find.byType(TextField), '我的本地评论');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('评论 1'), findsOneWidget);

    await tester.tap(find.text('回复').first);
    await tester.enterText(find.byType(TextField), '我的本地回复');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('我的本地回复'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await openSheet();
    expect(find.text('我的本地评论'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await tester.tap(find.text('展开 1 条回复'));
    await tester.pumpAndSettle();
    expect(find.text('我的本地回复'), findsOneWidget);

    await tester.tap(find.byTooltip('删除评论').first);
    await tester.pumpAndSettle();
    expect(find.text('我的本地评论'), findsNothing);
    expect(find.text('评论 0'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await openSheet();
    expect(find.text('我的本地评论'), findsNothing);
  });

  testWidgets('sharing a paper calls the service and updates its count',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final feed = PaperFeedController(const ArxivSeedRepository());
    final interactions = PaperInteractionController();
    final comments = PaperCommentController();
    final shareService = _FakePaperShareService(PaperShareResult.copied);
    addTearDown(feed.dispose);
    addTearDown(interactions.dispose);
    addTearDown(comments.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PapersScreen(
            readingController: PaperReadingController(),
            feedController: feed,
            interactionController: interactions,
            commentController: comments,
            aiService: const _FakePaperAiService(),
            translationServiceFactory:
                const _FakePaperTranslationServiceFactory(),
            shareService: shareService,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('paper-action-share')));
    await tester.pumpAndSettle();

    expect(shareService.payloads, hasLength(1));
    expect(shareService.payloads.single.subject, feed.papers.first.title);
    expect(interactions.shareCountDelta(feed.papers.first.id), 1);
    expect(find.text('分享内容已复制'), findsOneWidget);
  });

  testWidgets('topic filter stays compact and only appears in recommendations',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    expect(find.byKey(const ValueKey('paper-topic-filter')), findsOneWidget);
    expect(find.text('LLM'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('paper-primary-category-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-topic-filter')), findsNothing);
    expect(find.text('还没有关注作者'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('paper-primary-category-0')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-topic-filter')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('paper-topic-filter')));
    await tester.pumpAndSettle();

    expect(find.text('研究领域'), findsOneWidget);
    expect(find.text('全部领域'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('paper-topic-choice-AI Agent')),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('研究领域：AI Agent'), findsOneWidget);
  });

  testWidgets('search detail returns to search and keeps its history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final historyRepository = InMemoryPaperSearchHistoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PaperFlowShell(
          searchHistoryRepository: historyRepository,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paper-search-field')),
      'Milmer',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('paper-search-result-2502.00547')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('paper-search-result-2502.00547')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('paper-title-2502.00547')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('paper-detail-2502.00547')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('papers-header')), findsNothing);
    expect(find.byKey(const ValueKey('bottom-nav-0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('paper-detail-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('paper-search-result-2502.00547')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    expect(find.text('Milmer'), findsOneWidget);
  });

  testWidgets('paper AI sessions appear in the global chat entry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperAiSessionRepository();
    final paper = const ArxivSeedRepository().getAll().first;
    await repository.save(paper.id, const [
      PaperAiMessage(fromUser: true, content: '解释这篇论文'),
      PaperAiMessage(fromUser: false, content: '这是论文回答'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PaperFlowShell(
          aiService: const _FakePaperAiService(),
          aiSessionRepository: repository,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-chat-home-title')), findsOneWidget);
    expect(find.text('PaperFlow 主聊天'), findsOneWidget);
    expect(find.text(paper.title), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('ai-session-${paper.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('global-paper-ai-chat')), findsOneWidget);
  });

  testWidgets('main AI chat stays pinned above paper sessions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: PaperFlowShell(
          aiService: _FakePaperAiService(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-ai-chat')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
    await tester.pumpAndSettle();
    expect(find.text('主聊天'), findsOneWidget);
    expect(find.text('今天想研究什么？'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-input')), findsOneWidget);
  });
  testWidgets('AI session left swipe can pin and delete', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperAiSessionRepository();
    final paper = const ArxivSeedRepository().getAll().first;
    await repository.save(paper.id, const [
      PaperAiMessage(fromUser: true, content: '分析这篇论文'),
      PaperAiMessage(fromUser: false, content: '会话回答'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PaperFlowShell(
          aiService: const _FakePaperAiService(),
          aiSessionRepository: repository,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();

    final sessionCard = find.byKey(ValueKey('ai-session-${paper.id}'));
    await tester.drag(sessionCard, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('ai-session-pin-${paper.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('ai-session-delete-${paper.id}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('ai-session-pin-${paper.id}')));
    await tester.pumpAndSettle();
    expect((await repository.listSessions()).single.pinned, isTrue);

    await tester.drag(sessionCard, const Offset(-180, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('ai-session-delete-${paper.id}')));
    await tester.pumpAndSettle();
    expect(find.text('删除对话？'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-ai-session')),
    );
    await tester.pumpAndSettle();

    expect(await repository.listSessions(), isEmpty);
    expect(sessionCard, findsNothing);
    expect(find.byKey(const ValueKey('main-ai-chat')), findsOneWidget);
  });
}

class _FakePaperLinkService implements PaperLinkService {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class _ControlledCommentWidgetRepository implements PaperCommentRepository {
  final Completer<void> _saveCompleter = Completer<void>();

  @override
  Future<PaperCommentSnapshot> load(String paperId) async =>
      const PaperCommentSnapshot(comments: [], hasStoredValue: false);

  @override
  Future<void> save(
    String paperId,
    List<PaperCommentRecord> comments,
  ) async {
    await _saveCompleter.future;
    throw const PaperCommentPersistenceException('保存评论失败');
  }

  void failSave() => _saveCompleter.complete();
}

class _ControlledInteractionWidgetRepository
    implements PaperInteractionRepository {
  final Completer<void> _saveCompleter = Completer<void>();

  @override
  Future<PaperInteractionSnapshot> load() async => PaperInteractionSnapshot();

  @override
  Future<void> save(PaperInteractionSnapshot snapshot) async {
    await _saveCompleter.future;
    throw const PaperInteractionPersistenceException('保存互动失败');
  }

  void failSave() => _saveCompleter.complete();
}

class _FakePaperShareService implements PaperShareService {
  _FakePaperShareService(this.result);

  final PaperShareResult result;
  final List<PaperSharePayload> payloads = [];

  @override
  Future<PaperShareResult> share(PaperSharePayload payload) async {
    payloads.add(payload);
    return result;
  }
}

class _FakePaperAiService implements PaperAiService {
  const _FakePaperAiService();

  @override
  Future<String> answer({
    required ChatContext context,
    required List<PaperAiMessage> conversation,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return '**DeepSeek Markdown**\n\n- ${context.title}\n- ${conversation.last.content}';
  }
}

class _FakePaperTranslationServiceFactory
    implements PaperTranslationServiceFactory {
  const _FakePaperTranslationServiceFactory({
    this.content = '**DeepSeek 中文翻译**',
  });

  final String content;

  @override
  PaperTranslationService create() => _FakePaperTranslationService(content);
}

class _FakePaperTranslationService implements PaperTranslationService {
  const _FakePaperTranslationService(this.content);

  final String content;

  @override
  Stream<String> translateAbstract(Paper paper) async* {
    yield content;
  }

  @override
  void cancelActiveTranslation() {}
}

class _TestPaperRepository implements PaperRepository {
  const _TestPaperRepository(this.paper);

  final Paper paper;

  @override
  List<Paper> getAll() => [paper];
}

Paper _testPaper(String abstractText) {
  return Paper(
    id: 'test-paper',
    venue: 'TestConf 2026',
    title: 'A Test Paper for Reading Layout',
    authors: const ['Alex Chen', 'Lin Zhang'],
    firstAffiliation: 'PaperFlow Lab',
    topics: const ['Testing'],
    abstractText: abstractText,
    chineseAbstractMarkdown: '**中文摘要**',
    relatedPapers: const [],
    readMinutes: 5,
    citations: 0,
    likes: 0,
    comments: 0,
    saves: 0,
    shares: 0,
  );
}
