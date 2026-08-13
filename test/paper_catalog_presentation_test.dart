import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/papers/presentation/papers_screen.dart';

import 'support/paper_presentation_test_support.dart';

void main() {
  testWidgets('paper layout switches between fullscreen and grid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SparkApp(showSplash: false));
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('paper-feed'))).height,
      greaterThan(700),
    );
    expect(find.textContaining('被引'), findsNothing);
    expect(find.text('摘要'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('papers-view-mode-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-grid')), findsOneWidget);
    expect(find.text('论文'), findsOneWidget);

    await tester.tap(find.textContaining('Perturbation Effects on Robustness'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-detail-back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paper-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-grid')), findsOneWidget);
    expect(find.text('论文'), findsOneWidget);
  });

  testWidgets('paper feed is clipped below the fixed header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SparkApp(showSplash: false));
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

  testWidgets('paper grid loads the next page near the scroll boundary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = _GridPagedPaperCatalogRepository();
    final feed = PaperFeedController.fromPapers(
      const [],
      catalogRepository: catalog,
    );
    final interactions = PaperInteractionController();
    final comments = PaperCommentController();
    final reading = PaperReadingController();
    addTearDown(feed.dispose);
    addTearDown(interactions.dispose);
    addTearDown(comments.dispose);
    addTearDown(reading.dispose);

    await feed.initializeCatalog();
    feed.toggleGridMode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PapersScreen(
            readingController: reading,
            feedController: feed,
            interactionController: interactions,
            commentController: comments,
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

    await tester.fling(
      find.byKey(const ValueKey('paper-grid')),
      const Offset(0, -5000),
      5000,
    );
    await tester.pumpAndSettle();
    await feed.flushCatalogOperations();

    expect(catalog.queries.map((query) => query.offset), [0, 20]);
    expect(feed.papers, hasLength(40));
  });

  testWidgets(
    'channel bar keeps fixed channels and opens the channel manager',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const SparkApp(showSplash: false));
      await tester.pump();

      expect(find.text('推荐'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('paper-channel-manage')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('paper-channel-1')));
      await tester.pumpAndSettle();
      expect(find.text('还没有关注作者'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('paper-channel-manage')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('paper-channel-0')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paper-channel-manage')));
      await tester.pumpAndSettle();
      expect(find.text('频道管理'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('paper-channel-subject-cs.AI')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('paper-channel-manager-close')),
      );
      await tester.pumpAndSettle();

      expect(find.text('人工智能'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paper-channel-3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paper-feed')), findsOneWidget);
    },
  );
}

class _GridPagedPaperCatalogRepository implements PaperCatalogRepository {
  final List<PaperFeedQuery> queries = [];

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    queries.add(query);
    final start = query.offset;
    return PaperPage(
      papers: List.generate(20, (index) => _gridPaper(start + index)),
      source: PaperPageSource.remote,
      nextOffset: start == 0 ? 20 : null,
    );
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

Paper _gridPaper(int index) => Paper(
      id: 'grid-paper-$index',
      title: 'Grid paper $index with a sufficiently descriptive title',
      authors: const ['Researcher'],
      affiliations: const ['Spark Lab'],
      subjects: const ['cs.AI'],
      abstractText: 'Abstract for grid paper $index.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
      publishedAt: DateTime.utc(2026, 1, 1),
      source: 'arxiv',
    );
