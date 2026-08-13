import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/papers/presentation/papers_screen.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_action_bar.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_reader_view.dart';

import 'support/paper_presentation_test_support.dart';

void main() {
  testWidgets('paper title copies on tap while body remains selectable', (
    tester,
  ) async {
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

    await tester.pumpWidget(const SparkApp(showSplash: false));
    await tester.pump();

    const title =
        'Corruption Robust Offline Reinforcement Learning with Human Feedback';
    await tester.tap(find.byKey(const ValueKey('paper-title-2402.06734')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('论文题目已复制'), findsNothing);
    expect(copiedText, title);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('paper metadata exposes the primary reading path', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final linkService = _FakePaperLinkService();

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(linkService: linkService),
      ),
    );
    await tester.pump();

    expect(find.text('关注作者'), findsOneWidget);
    expect(find.textContaining('· arXiv'), findsNothing);
    expect(find.textContaining('被引'), findsNothing);
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

  testWidgets('paper tabs animate content and actions keep shared state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(
          translationServiceFactory: const FakePaperTranslationServiceFactory(),
        ),
      ),
    );
    await tester.pump();

    final pagesSize = tester.getSize(
      find.byKey(const ValueKey('paper-tab-pages')).first,
    );
    await tester.tap(find.text('摘要').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byKey(const ValueKey('paper-tab-pages')).first),
      pagesSize,
    );
    await tester.pumpAndSettle();
    expect(find.text('中文摘要内容'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_rounded), findsWidgets);
  });

  testWidgets('each paper in the vertical feed starts on the original tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SparkApp(showSplash: false));
    await tester.pump();

    final firstReader = find.byType(PaperReaderView).first;
    final tabs = find
        .descendant(
          of: firstReader,
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    await tester.drag(tabs, const Offset(-520, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: firstReader, matching: find.text('相关论文')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: firstReader,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SparkSegmentedControl && widget.selectedIndex == 5,
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
          .widget<SparkSegmentedControl>(
            find.byType(SparkSegmentedControl).hitTestable(),
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
          .widget<SparkSegmentedControl>(
            find.byType(SparkSegmentedControl).hitTestable(),
          )
          .selectedIndex,
      0,
    );
  });

  testWidgets('long Chinese interpretation can open the full reader', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(
          translationServiceFactory: FakePaperTranslationServiceFactory(
            content: List.filled(160, '这是中文解读正文').join(' '),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('摘要').first);
    await tester.pumpAndSettle();

    expect(find.text('展开全文'), findsOneWidget);
    final refreshBounds = tester.getRect(
      find.byKey(const ValueKey('paper-translation-refresh')),
    );
    final expandBounds = tester.getRect(find.text('展开全文'));
    expect(refreshBounds.center.dy, closeTo(expandBounds.center.dy, 0.1));
    expect(refreshBounds.left, lessThan(expandBounds.left));
    await tester.tap(find.text('展开全文'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-full-reader')), findsOneWidget);
    expect(find.text('摘要'), findsOneWidget);
  });

  testWidgets('translation action stays bottom-left while refreshing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(
          translationServiceFactory: const FakePaperTranslationServiceFactory(
            content: '简短中文摘要',
            delay: Duration(seconds: 1),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('摘要').first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('展开全文'), findsNothing);
    final pagesBottom = tester
        .getRect(find.byKey(const ValueKey('paper-tab-pages')).first)
        .bottom;
    var actionBounds = tester.getRect(
      find.byKey(const ValueKey('paper-translation-refresh')),
    );
    expect(pagesBottom - actionBounds.center.dy, closeTo(18, 0.1));

    await tester.tap(find.byKey(const ValueKey('paper-translation-refresh')));
    await tester.pump();

    expect(find.text('停止'), findsOneWidget);
    actionBounds = tester.getRect(
      find.byKey(const ValueKey('paper-translation-refresh')),
    );
    expect(pagesBottom - actionBounds.center.dy, closeTo(18, 0.1));

    await tester.tap(find.byKey(const ValueKey('paper-translation-refresh')));
    await tester.pump();
    expect(find.text('停止'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'abstract expansion appears only when text exceeds its viewport',
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
              aiDiscussionBuilder: paperAiDiscussionBuilder(
                const FakeChatAiService(),
              ),
              keywordService: const FakeChatAiService(),
              translationServiceFactory:
                  const FakePaperTranslationServiceFactory(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('展开全文'), findsOneWidget);
      await tester.tap(find.text('展开全文'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paper-full-reader')), findsOneWidget);
      expect(find.text('Abstract'), findsOneWidget);

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
              aiDiscussionBuilder: paperAiDiscussionBuilder(
                const FakeChatAiService(),
              ),
              keywordService: const FakeChatAiService(),
              translationServiceFactory:
                  const FakePaperTranslationServiceFactory(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('展开全文'), findsNothing);
    },
  );
}

class _FakePaperLinkService implements PaperLinkService {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
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
    affiliations: const ['Spark Lab'],
    contentKeywords: const ['Testing'],
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
