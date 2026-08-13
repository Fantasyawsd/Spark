import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/papers.dart';
import 'package:spark/src/features/search/application/paper_search_controller.dart';
import 'package:spark/src/features/search/data/in_memory_paper_search_history_repository.dart';
import 'package:spark/src/features/search/presentation/paper_search_screen.dart';

void main() {
  testWidgets('shows the empty search history state before a query', (
    tester,
  ) async {
    final controller = PaperSearchController(
      papers: const [],
      historyRepository: InMemoryPaperSearchHistoryRepository(),
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PaperSearchScreen(
          controller: controller,
          onPaperSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('暂无搜索历史'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-search-results')), findsNothing);
  });

  testWidgets('shows the catalog error when a remote search fails', (
    tester,
  ) async {
    final controller = PaperSearchController(
      papers: const [],
      historyRepository: InMemoryPaperSearchHistoryRepository(),
      catalogRepository: const _FailingCatalogRepository(),
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PaperSearchScreen(
          controller: controller,
          onPaperSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paper-search-field')),
      'new topic',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paper-search-empty')), findsOneWidget);
    expect(find.text('搜索服务暂时不可用。'), findsOneWidget);
  });
}

class _FailingCatalogRepository implements PaperCatalogRepository {
  const _FailingCatalogRepository();

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);

  @override
  Future<PaperPage> search(PaperSearchQuery query) {
    throw StateError('search unavailable');
  }
}
