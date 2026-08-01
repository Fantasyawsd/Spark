import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/papers/data/cache/in_memory_paper_cache_store.dart';
import 'package:paperflow/src/features/papers/data/offline_first_paper_catalog_repository.dart';
import 'package:paperflow/src/features/papers/data/providers/arxiv/arxiv_atom_dto.dart';
import 'package:paperflow/src/features/papers/data/providers/arxiv/arxiv_catalog_source.dart';
import 'package:paperflow/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:paperflow/src/features/papers/domain/paper_catalog.dart';

void main() {
  late _FakeArxivSource remote;
  late InMemoryPaperCacheStore cache;
  late OfflineFirstPaperCatalogRepository repository;

  setUp(() {
    remote = _FakeArxivSource();
    cache = InMemoryPaperCacheStore();
    repository = OfflineFirstPaperCatalogRepository(
      remoteSource: remote,
      cacheStore: cache,
      seedRepository: const ArxivSeedRepository(),
      clock: () => DateTime.utc(2024, 3, 1),
    );
  });

  test('remote feed is mapped and written to cache', () async {
    remote.feed = _page('2401.00001');

    final page = await repository.loadFeed(
      const PaperFeedQuery(category: 'cs.AI', limit: 10),
    );

    expect(page.source, PaperPageSource.remote);
    expect(page.papers.single.id, '2401.00001');
    expect(remote.lastCategory, 'cs.AI');
    expect(
      (await cache.readPage('feed|category=cs.AI|offset=0|limit=10')),
      isNotNull,
    );
  });

  test('remote failure returns stale query cache', () async {
    remote.feed = _page('2401.00001');
    await repository.loadFeed(
      const PaperFeedQuery(category: 'cs.AI', limit: 10),
    );
    remote.error = StateError('offline');

    final page = await repository.loadFeed(
      const PaperFeedQuery(category: 'cs.AI', limit: 10),
    );

    expect(page.source, PaperPageSource.cache);
    expect(page.isStale, isTrue);
    expect(page.isOffline, isTrue);
    expect(page.papers.single.id, '2401.00001');
  });

  test('remote failure without cache falls back to seed papers', () async {
    remote.error = StateError('offline');

    final page = await repository.loadFeed(
      const PaperFeedQuery(limit: 2),
    );

    expect(page.source, PaperPageSource.seed);
    expect(page.isOffline, isTrue);
    expect(page.papers, hasLength(2));
    expect(page.error, isNotNull);
  });

  test('search falls back to matching seed papers', () async {
    remote.error = StateError('offline');

    final page = await repository.search(
      const PaperSearchQuery(term: 'Milmer', limit: 20),
    );

    expect(page.source, PaperPageSource.seed);
    expect(page.papers.map((paper) => paper.id), contains('2502.00547'));
  });

  test('findById uses cache before making a remote request', () async {
    remote.detail = _paper('2401.00001');
    final first = await repository.findById('2401.00001');
    remote.detail = null;
    remote.error = StateError('offline');

    final second = await repository.findById('2401.00001');

    expect(first?.id, '2401.00001');
    expect(second?.id, '2401.00001');
    expect(remote.detailRequests, 1);
  });
}

class _FakeArxivSource implements ArxivCatalogSource {
  ArxivAtomPageDto? feed;
  ArxivAtomPaperDto? detail;
  Object? error;
  String? lastCategory;
  int detailRequests = 0;

  @override
  Future<ArxivAtomPageDto> loadLatest({
    String? category,
    required int offset,
    required int limit,
  }) async {
    lastCategory = category;
    if (error != null) throw error!;
    return feed ?? _page('2401.00001');
  }

  @override
  Future<ArxivAtomPageDto> search({
    required String term,
    required int offset,
    required int limit,
  }) async {
    if (error != null) throw error!;
    return feed ?? _page('2401.00001');
  }

  @override
  Future<ArxivAtomPaperDto?> findById(String paperId) async {
    detailRequests++;
    if (error != null) throw error!;
    return detail;
  }
}

ArxivAtomPageDto _page(String id) {
  return ArxivAtomPageDto(
    entries: [_paper(id)],
    startIndex: 0,
    itemsPerPage: 1,
    totalResults: 1,
    nextOffset: null,
  );
}

ArxivAtomPaperDto _paper(String id) {
  return ArxivAtomPaperDto(
    id: id,
    title: 'Remote paper',
    summary: 'A remote abstract.',
    authors: const ['Remote Author'],
    affiliations: const ['PaperFlow Lab'],
    categories: const ['cs.AI'],
    primaryCategory: 'cs.AI',
    publishedAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 2),
    paperUrl: 'https://arxiv.org/abs/$id',
    pdfUrl: 'https://arxiv.org/pdf/$id',
  );
}
