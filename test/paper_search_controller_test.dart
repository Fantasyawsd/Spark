import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';

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
      await controller.submitQuery('2306.12345');

      expect(controller.results, isEmpty);
      expect(controller.resultsError?.message, '按 arXiv ID 获取论文失败。');
    });
  });

  test('file search history survives repository recreation', () async {
    final directory =
        await Directory.systemTemp.createTemp('spark-search-');
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
  });

  final Paper? paperById;
  final bool throwOnFindById;
  final List<String> searchTerms = [];
  final List<String> findByIdCalls = [];

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);

  @override
  Future<PaperPage> search(PaperSearchQuery query) async {
    searchTerms.add(query.term);
    return PaperPage(papers: const [], source: PaperPageSource.remote);
  }

  @override
  Future<Paper?> findById(String paperId) async {
    findByIdCalls.add(paperId);
    if (throwOnFindById) throw StateError('fetch failed');
    return paperById;
  }
}
