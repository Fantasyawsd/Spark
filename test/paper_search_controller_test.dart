import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/papers/data/demo_paper_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';
import 'package:spark/src/features/search/application/paper_search_controller.dart';
import 'package:spark/src/features/search/data/file_paper_search_history_repository.dart';
import 'package:spark/src/features/search/data/in_memory_paper_search_history_repository.dart';
import 'package:spark/src/features/search/domain/paper_search_history_repository.dart';

void main() {
  group('PaperSearchController', () {
    late InMemoryPaperSearchHistoryRepository historyRepository;
    late PaperSearchController controller;

    setUp(() {
      historyRepository = InMemoryPaperSearchHistoryRepository(['Mamba']);
      controller = PaperSearchController(
        papers: const DemoPaperRepository().getAll(),
        historyRepository: historyRepository,
        debounceDuration: const Duration(milliseconds: 5),
      );
    });

    tearDown(() => controller.dispose());

    test('matches title, author, venue and topic without case sensitivity',
        () async {
      await controller.initialize();

      await controller.submitQuery('lOrA');
      expect(controller.results.first.id, 'lora-2021');
      expect(
        controller.results.map((paper) => paper.id),
        contains('qlora-2023'),
      );

      await controller.submitQuery('Tri Dao');
      expect(controller.results.single.id, 'mamba-2023');

      await controller.submitQuery('ICCV');
      expect(controller.results.single.id, 'segment-anything-2023');

      await controller.submitQuery('segmentation');
      expect(controller.results.single.id, 'segment-anything-2023');
    });

    test('debounces input and exposes an empty result state', () async {
      controller.updateQuery('LoRA');
      expect(controller.results, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.results.first.id, 'lora-2021');

      await controller.submitQuery('not-a-real-paper');
      expect(controller.results, isEmpty);
    });

    test('deduplicates, removes and clears persisted history', () async {
      await controller.initialize();
      await controller.submitQuery('mamba');

      expect(controller.history, ['mamba']);
      await controller.removeHistory('mamba');
      expect(await historyRepository.load(), isEmpty);

      await controller.submitQuery('LoRA');
      await controller.submitQuery('ICLR');
      await controller.clearHistory();
      expect(await historyRepository.load(), isEmpty);
    });
  });

  group('PaperSearchController with arXiv ID queries', () {
    late InMemoryPaperSearchHistoryRepository historyRepository;
    late _FakeCatalogRepository catalog;
    late PaperSearchController controller;

    setUp(() {
      historyRepository = InMemoryPaperSearchHistoryRepository();
      catalog = _FakeCatalogRepository(
        paperById: DemoPaperRepository().getAll().first,
      );
      controller = PaperSearchController(
        papers: const DemoPaperRepository().getAll(),
        historyRepository: historyRepository,
        catalogRepository: catalog,
        debounceDuration: const Duration(milliseconds: 5),
      );
    });

    tearDown(() => controller.dispose());

    test('an arXiv ID query fetches by id and returns a single result',
        () async {
      await controller.initialize();
      await controller.submitQuery('2306.12345');

      expect(catalog.findByIdCalls, ['2306.12345']);
      expect(catalog.searchTerms, isEmpty);
      expect(controller.results, hasLength(1));
      expect(controller.results.first.id, 'lora-2021');
      expect(controller.hasMoreResults, isFalse);
    });

    test('normalizes arXiv ID input forms before fetching', () async {
      await controller.submitQuery('arXiv:2306.12345v2');
      expect(catalog.findByIdCalls, ['2306.12345']);
    });

    test('a keyword query still goes through remote search', () async {
      await controller.submitQuery('LoRA');
      expect(catalog.searchTerms, ['LoRA']);
      expect(catalog.findByIdCalls, isEmpty);
    });

    test('a keyword failure reports once and keeps local fallback results',
        () async {
      catalog = _FakeCatalogRepository(
        paperById: null,
        throwOnSearch: true,
      );
      controller = PaperSearchController(
        papers: const DemoPaperRepository().getAll(),
        historyRepository: historyRepository,
        catalogRepository: catalog,
        debounceDuration: const Duration(milliseconds: 5),
      );
      final events = <SparkDiagnosticEvent>[];

      await SparkDiagnostics.runWithSink(
        events.add,
        () => controller.submitQuery('LoRA'),
      );

      expect(controller.results, isNotEmpty);
      expect(controller.resultsError?.message, '搜索服务暂时不可用。');
      expect(
        events.map((event) => event.operation),
        [SparkDiagnosticOperation.paperSearchLoad],
      );
    });

    test('an unknown arXiv ID yields an empty result without an error',
        () async {
      catalog = _FakeCatalogRepository(paperById: null);
      controller = PaperSearchController(
        papers: const DemoPaperRepository().getAll(),
        historyRepository: historyRepository,
        catalogRepository: catalog,
        debounceDuration: const Duration(milliseconds: 5),
      );
      await controller.submitQuery('2306.99999');

      expect(controller.results, isEmpty);
      expect(controller.resultsError, isNull);
    });

    test('a fetch failure surfaces the arXiv ID error message', () async {
      catalog = _FakeCatalogRepository(
        paperById: DemoPaperRepository().getAll().first,
        throwOnFindById: true,
      );
      controller = PaperSearchController(
        papers: const DemoPaperRepository().getAll(),
        historyRepository: historyRepository,
        catalogRepository: catalog,
        debounceDuration: const Duration(milliseconds: 5),
      );
      final events = <SparkDiagnosticEvent>[];

      await SparkDiagnostics.runWithSink(
        events.add,
        () => controller.submitQuery('2306.12345'),
      );

      expect(controller.results, isEmpty);
      expect(controller.resultsError?.message, '按 arXiv ID 获取论文失败。');
      expect(
        events.map((event) => event.operation),
        [SparkDiagnosticOperation.paperSearchFindById],
      );
    });
  });

  test('pagination failures report once and preserve existing results',
      () async {
    final papers = const DemoPaperRepository().getAll();
    final catalog = _FailingPaginationCatalogRepository(papers.first);
    final controller = PaperSearchController(
      papers: papers,
      historyRepository: InMemoryPaperSearchHistoryRepository(),
      catalogRepository: catalog,
    );
    addTearDown(controller.dispose);
    await controller.submitQuery('remote query');
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(
      events.add,
      controller.loadMoreResults,
    );

    expect(controller.results.single.id, papers.first.id);
    expect(controller.resultsError?.message, '无法加载更多搜索结果。');
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperSearchLoadMore],
    );
  });

  test('ignores stale pagination from an older same-term search', () async {
    final papers = const DemoPaperRepository().getAll();
    final catalog = _SequencedSearchCatalogRepository(
      firstPaper: papers[0],
      refreshedPaper: papers[1],
      staleMorePaper: papers[2],
    );
    final controller = PaperSearchController(
      papers: papers,
      historyRepository: InMemoryPaperSearchHistoryRepository(),
      catalogRepository: catalog,
    );
    addTearDown(controller.dispose);

    await controller.submitQuery('same term');
    final stalePagination = controller.loadMoreResults();
    final refreshedSearch = controller.submitQuery('same term');
    catalog.completeRefresh();
    await refreshedSearch;

    catalog.completeStalePagination();
    await stalePagination;

    expect(controller.results.map((paper) => paper.id), [papers[1].id]);
    expect(controller.loadingMoreResults, isFalse);
  });

  test('a new first page immediately invalidates the previous next offset',
      () async {
    final papers = const DemoPaperRepository().getAll();
    final catalog = _SequencedSearchCatalogRepository(
      firstPaper: papers[0],
      refreshedPaper: papers[1],
      staleMorePaper: papers[2],
    );
    final controller = PaperSearchController(
      papers: papers,
      historyRepository: InMemoryPaperSearchHistoryRepository(),
      catalogRepository: catalog,
    );
    addTearDown(controller.dispose);

    await controller.submitQuery('same term');
    expect(controller.hasMoreResults, isTrue);

    final refreshedSearch = controller.submitQuery('same term');
    final invalidatedImmediately = !controller.hasMoreResults;
    final overlappingPagination = controller.loadMoreResults();
    await Future<void>.delayed(Duration.zero);
    catalog.completeRefresh();
    catalog.completeStalePagination();
    await Future.wait([refreshedSearch, overlappingPagination]);

    expect(invalidatedImmediately, isTrue);
    expect(catalog.paginationCalls, 0);
    expect(controller.results.map((paper) => paper.id), [papers[1].id]);
    expect(controller.loadingResults, isFalse);
    expect(controller.loadingMoreResults, isFalse);
  });

  test('query edits immediately invalidate a pending first page', () async {
    final papers = const DemoPaperRepository().getAll();
    final catalog = _PendingFirstPageCatalogRepository();
    final controller = PaperSearchController(
      papers: papers,
      historyRepository: InMemoryPaperSearchHistoryRepository(),
      catalogRepository: catalog,
      debounceDuration: const Duration(days: 1),
    );
    addTearDown(controller.dispose);

    final staleSearch = controller.submitQuery('old term');
    controller.updateQuery('new term');
    catalog.complete(papers.first);
    await staleSearch;

    expect(controller.query, 'new term');
    expect(controller.results, isEmpty);
    expect(controller.loadingResults, isFalse);
    expect(controller.hasMoreResults, isFalse);
    expect(controller.history, isEmpty);
  });

  test('finishes pending history initialization safely after dispose',
      () async {
    final historyRepository = _PendingSearchHistoryRepository();
    final controller = PaperSearchController(
      papers: const DemoPaperRepository().getAll(),
      historyRepository: historyRepository,
    );
    final initialize = controller.initialize();

    controller.dispose();
    historyRepository.completeLoad(['LoRA']);

    await expectLater(initialize, completes);
  });

  test('replays a submitted query after pending history initialization',
      () async {
    final historyRepository = _PendingSearchHistoryRepository();
    final controller = PaperSearchController(
      papers: const DemoPaperRepository().getAll(),
      historyRepository: historyRepository,
    );
    addTearDown(controller.dispose);
    final initialize = controller.initialize();

    final submit = controller.submitQuery('LoRA');
    expect(historyRepository.savedHistories, isEmpty);
    historyRepository.completeLoad(['Mamba']);

    await Future.wait([initialize, submit]);
    expect(controller.history, ['LoRA', 'Mamba']);
    expect(historyRepository.savedHistories, [
      ['LoRA', 'Mamba'],
    ]);
  });

  test('replays pending history mutations in their original order', () async {
    final historyRepository = _PendingSearchHistoryRepository();
    final controller = PaperSearchController(
      papers: const DemoPaperRepository().getAll(),
      historyRepository: historyRepository,
    );
    addTearDown(controller.dispose);
    final initialize = controller.initialize();

    final remove = controller.removeHistory('Mamba');
    final clear = controller.clearHistory();
    final submit = controller.submitQuery('LoRA');
    historyRepository.completeLoad(['Mamba', 'ICLR']);

    await Future.wait([initialize, remove, clear, submit]);
    expect(controller.history, ['LoRA']);
    expect(historyRepository.savedHistories, everyElement(['LoRA']));
  });

  test('serial history writes ignore an older failure after a newer mutation',
      () async {
    final historyRepository = _SequencedSearchHistoryRepository();
    final controller = PaperSearchController(
      papers: const DemoPaperRepository().getAll(),
      historyRepository: historyRepository,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final first = controller.submitQuery('LoRA');
    await historyRepository.firstSaveStarted;
    final second = controller.submitQuery('Mamba');
    await Future<void>.delayed(Duration.zero);

    expect(historyRepository.savedHistories, [
      ['LoRA'],
    ]);
    historyRepository.failFirstSave(StateError('disk unavailable'));
    await historyRepository.secondSaveStarted;
    historyRepository.completeSecondSave();

    await Future.wait([first, second]);
    expect(historyRepository.savedHistories, [
      ['LoRA'],
      ['Mamba', 'LoRA'],
    ]);
    expect(controller.historyError, isNull);
  });

  test('normalizes an unexpected history save failure', () async {
    final controller = PaperSearchController(
      papers: const DemoPaperRepository().getAll(),
      historyRepository: _UnexpectedFailureSearchHistoryRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final events = <SparkDiagnosticEvent>[];

    await expectLater(
      SparkDiagnostics.runWithSink(
        events.add,
        () => controller.submitQuery('LoRA'),
      ),
      completes,
    );

    expect(controller.historyError, '无法保存搜索历史。');
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperSearchHistorySave],
    );
    expect(events.single.severity, SparkDiagnosticSeverity.warning);
  });

  test('normalizes and reports an unexpected history load failure', () async {
    final controller = PaperSearchController(
      papers: const DemoPaperRepository().getAll(),
      historyRepository: _UnexpectedLoadFailureSearchHistoryRepository(),
    );
    addTearDown(controller.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, controller.initialize);

    expect(controller.historyError, '无法读取搜索历史。');
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperSearchHistoryLoad],
    );
    expect(events.single.severity, SparkDiagnosticSeverity.warning);
  });

  test('ignores pending pagination after dispose', () async {
    final papers = const DemoPaperRepository().getAll();
    final catalog = _PendingPaginationCatalogRepository(papers.first);
    final controller = PaperSearchController(
      papers: papers,
      historyRepository: InMemoryPaperSearchHistoryRepository(),
      catalogRepository: catalog,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.submitQuery('pending');
    final pagination = controller.loadMoreResults();
    final notificationsBeforeDispose = notifications;
    final resultsBeforeDispose = controller.results;
    controller.dispose();
    catalog.completePagination(papers[1]);

    await expectLater(pagination, completes);
    expect(controller.results, same(resultsBeforeDispose));
    expect(notifications, notificationsBeforeDispose);
  });

  test('file search history survives repository recreation', () async {
    final directory = await Directory.systemTemp.createTemp('spark-search-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}history.json');

    await FilePaperSearchHistoryRepository(file: file).save(['LoRA', 'Mamba']);
    final restored = await FilePaperSearchHistoryRepository(file: file).load();

    expect(restored, ['LoRA', 'Mamba']);
  });
}

class _FakeCatalogRepository implements PaperCatalogRepository {
  _FakeCatalogRepository({
    required this.paperById,
    this.throwOnFindById = false,
    this.throwOnSearch = false,
  });

  final Paper? paperById;
  final bool throwOnFindById;
  final bool throwOnSearch;
  final List<String> searchTerms = [];
  final List<String> findByIdCalls = [];

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);

  @override
  Future<PaperPage> search(PaperSearchQuery query) async {
    searchTerms.add(query.term);
    if (throwOnSearch) throw StateError('search failed');
    return PaperPage(papers: const [], source: PaperPageSource.remote);
  }

  @override
  Future<Paper?> findById(String paperId) async {
    findByIdCalls.add(paperId);
    if (throwOnFindById) throw StateError('fetch failed');
    return paperById;
  }
}

class _FailingPaginationCatalogRepository implements PaperCatalogRepository {
  _FailingPaginationCatalogRepository(this.firstPaper);

  final Paper firstPaper;
  var searchCalls = 0;

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);

  @override
  Future<PaperPage> search(PaperSearchQuery query) async {
    searchCalls++;
    if (searchCalls > 1) throw StateError('pagination failed');
    return PaperPage(
      papers: [firstPaper],
      source: PaperPageSource.remote,
      nextOffset: 20,
    );
  }
}

class _SequencedSearchCatalogRepository implements PaperCatalogRepository {
  _SequencedSearchCatalogRepository({
    required this.firstPaper,
    required this.refreshedPaper,
    required this.staleMorePaper,
  });

  final Paper firstPaper;
  final Paper refreshedPaper;
  final Paper staleMorePaper;
  final _refresh = Completer<PaperPage>();
  final _stalePagination = Completer<PaperPage>();
  int _firstPageCalls = 0;
  int paginationCalls = 0;

  void completeRefresh() {
    _refresh.complete(
      PaperPage(papers: [refreshedPaper], source: PaperPageSource.remote),
    );
  }

  void completeStalePagination() {
    _stalePagination.complete(
      PaperPage(papers: [staleMorePaper], source: PaperPageSource.remote),
    );
  }

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);

  @override
  Future<PaperPage> search(PaperSearchQuery query) {
    if (query.offset > 0) {
      paginationCalls++;
      return _stalePagination.future;
    }
    _firstPageCalls++;
    if (_firstPageCalls == 1) {
      return Future.value(
        PaperPage(
          papers: [firstPaper],
          source: PaperPageSource.remote,
          nextOffset: 20,
        ),
      );
    }
    return _refresh.future;
  }
}

class _PendingSearchHistoryRepository implements PaperSearchHistoryRepository {
  final _load = Completer<List<String>>();
  final List<List<String>> savedHistories = [];

  void completeLoad(List<String> history) => _load.complete(history);

  @override
  Future<List<String>> load() => _load.future;

  @override
  Future<void> save(List<String> queries) async {
    savedHistories.add(List.of(queries));
  }
}

class _SequencedSearchHistoryRepository
    implements PaperSearchHistoryRepository {
  final List<List<String>> savedHistories = [];
  final _firstSaveStarted = Completer<void>();
  final _secondSaveStarted = Completer<void>();
  final _firstSave = Completer<void>();
  final _secondSave = Completer<void>();

  Future<void> get firstSaveStarted => _firstSaveStarted.future;
  Future<void> get secondSaveStarted => _secondSaveStarted.future;

  void failFirstSave(Object error) => _firstSave.completeError(error);
  void completeSecondSave() => _secondSave.complete();

  @override
  Future<List<String>> load() async => const [];

  @override
  Future<void> save(List<String> queries) {
    savedHistories.add(List.of(queries));
    if (savedHistories.length == 1) {
      _firstSaveStarted.complete();
      return _firstSave.future;
    }
    _secondSaveStarted.complete();
    return _secondSave.future;
  }
}

class _UnexpectedFailureSearchHistoryRepository
    implements PaperSearchHistoryRepository {
  @override
  Future<List<String>> load() async => const [];

  @override
  Future<void> save(List<String> queries) async {
    throw StateError('disk unavailable');
  }
}

class _UnexpectedLoadFailureSearchHistoryRepository
    implements PaperSearchHistoryRepository {
  @override
  Future<List<String>> load() async {
    throw StateError('disk unavailable');
  }

  @override
  Future<void> save(List<String> queries) async {}
}

class _PendingFirstPageCatalogRepository implements PaperCatalogRepository {
  final _page = Completer<PaperPage>();

  void complete(Paper paper) {
    _page.complete(
      PaperPage(
        papers: [paper],
        source: PaperPageSource.remote,
        nextOffset: 20,
      ),
    );
  }

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);

  @override
  Future<PaperPage> search(PaperSearchQuery query) => _page.future;
}

class _PendingPaginationCatalogRepository implements PaperCatalogRepository {
  _PendingPaginationCatalogRepository(this.firstPaper);

  final Paper firstPaper;
  final _pagination = Completer<PaperPage>();

  void completePagination(Paper paper) {
    _pagination.complete(
      PaperPage(papers: [paper], source: PaperPageSource.remote),
    );
  }

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);

  @override
  Future<PaperPage> search(PaperSearchQuery query) {
    if (query.offset > 0) return _pagination.future;
    return Future.value(
      PaperPage(
        papers: [firstPaper],
        source: PaperPageSource.remote,
        nextOffset: 20,
      ),
    );
  }
}
