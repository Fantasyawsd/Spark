import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_interaction_repository.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_reader_view.dart';
import 'package:spark/src/features/search/data/in_memory_paper_search_history_repository.dart';

void main() {
  testWidgets('related paper opens a fullscreen detail and returns to feed', (
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
    await tester.tap(find.text('相关论文').first);
    await tester.pumpAndSettle();

    final related = find.byKey(const ValueKey('related-paper-2404.01356'));
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

    final detailReader = find.byType(PaperReaderView).first;
    final detailTabs = find
        .descendant(
          of: detailReader,
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    await tester.drag(detailTabs, const Offset(-520, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('相关论文').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('related-paper-2402.06734')));
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

  testWidgets('saved paper detail returns to profile without moving the feed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final interactions = InMemoryPaperInteractionRepository(
      PaperInteractionSnapshot(savedPaperIds: {'2404.01356'}),
    );

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(
          interactionRepository: interactions,
        ),
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

  testWidgets(
    'selected paper navigation refreshes while returning to papers only navigates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final catalog = _NavigationRefreshPaperCatalogRepository();

      await tester.pumpWidget(
        SparkApp(
          showSplash: false,
          dependencies: SparkDependencies.preview(
            paperCatalogRepository: catalog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(catalog.queries, hasLength(1));
      expect(catalog.queries.single.forceRefresh, isFalse);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-0')));
      await tester.pumpAndSettle();

      expect(catalog.queries, hasLength(2));
      expect(catalog.queries.last.forceRefresh, isTrue);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-0')));
      await tester.pumpAndSettle();

      expect(catalog.queries, hasLength(2));
    },
  );

  testWidgets('search detail returns to search and keeps its history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final historyRepository = InMemoryPaperSearchHistoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SparkShell(
          dependencies: SparkDependencies.preview(
            searchHistoryRepository: historyRepository,
          ),
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
}

class _NavigationRefreshPaperCatalogRepository
    implements PaperCatalogRepository {
  final List<PaperFeedQuery> queries = [];

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    queries.add(query);
    return PaperPage(
      papers: [_gridPaper(queries.length)],
      source: PaperPageSource.remote,
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
