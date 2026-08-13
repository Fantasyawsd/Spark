import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/papers/data/cache/in_memory_paper_cache_store.dart';
import 'package:spark/src/features/papers/data/cache/paper_cache_record.dart';
import 'package:spark/src/features/papers/data/cache/paper_cache_store.dart';
import 'package:spark/src/features/papers/data/offline_first_paper_catalog_repository.dart';
import 'package:spark/src/features/papers/data/providers/arxiv/arxiv_atom_dto.dart';
import 'package:spark/src/features/papers/data/providers/arxiv/arxiv_atom_client.dart';
import 'package:spark/src/features/papers/data/providers/arxiv/arxiv_catalog_source.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';
import 'package:spark/src/features/papers/domain/paper_time_range.dart';

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
    expect(page.fetchedAt, DateTime.utc(2024, 3, 1));
    expect(page.papers.single.id, '2401.00001');
    expect(page.fetchedAt, DateTime.utc(2024, 3, 1));
    expect(remote.lastCategory, 'cs.AI');
    expect(
      (await cache.readPage(
        'feed|category=cs.AI|time=all|offset=0|limit=10',
      )),
      isNotNull,
    );
  });

  test('passes time bounds to remote and isolates cache keys', () async {
    remote.feed = _page('2401.00001');

    await repository.loadFeed(
      const PaperFeedQuery(
        category: 'cs.AI',
        timeRange: PaperTimeRange.last7Days(),
        limit: 10,
      ),
    );

    expect(remote.lastPublishedFrom, DateTime(2024, 2, 24));
    expect(remote.lastPublishedUntil, DateTime(2024, 3, 1, 23, 59, 59, 999));
    expect(
      await cache.readPage(
        'feed|category=cs.AI|time=last-7-days'
        '|window=2024-02-24..2024-03-01|offset=0|limit=10',
      ),
      isNotNull,
    );
  });

  test('relative time cache is not reused after its window moves', () async {
    var now = DateTime.utc(2024, 3, 1);
    repository = OfflineFirstPaperCatalogRepository(
      remoteSource: remote,
      cacheStore: cache,
      seedRepository: const ArxivSeedRepository(),
      clock: () => now,
    );
    remote.feed = _page('2401.00001');
    const query = PaperFeedQuery(
      category: 'cs.AI',
      timeRange: PaperTimeRange.last7Days(),
      limit: 10,
    );
    await repository.loadFeed(query);

    now = DateTime.utc(2024, 3, 21);
    remote.error = StateError('offline');
    final page = await repository.loadFeed(query);

    expect(page.source, PaperPageSource.seed);
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
    final events = <SparkDiagnosticEvent>[];

    final page = await SparkDiagnostics.runWithSink(
      events.add,
      () => repository.loadFeed(const PaperFeedQuery(limit: 2)),
    );

    expect(page.source, PaperPageSource.seed);
    expect(page.isOffline, isTrue);
    expect(page.papers, hasLength(2));
    expect(page.error, isNotNull);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCatalogArxivLoadFeed],
    );
  });

  test('server failures use a user-facing fallback message', () async {
    remote.error = const ArxivApiException(
      ArxivApiErrorKind.http,
      'arXiv 请求失败（HTTP 500）。',
    );

    final page = await repository.loadFeed(
      const PaperFeedQuery(limit: 2),
    );

    expect(page.error?.message, contains('已显示本地数据'));
    expect(page.error?.message, isNot(contains('HTTP 500')));
  });

  test('search falls back to matching seed papers', () async {
    remote.error = StateError('offline');
    final events = <SparkDiagnosticEvent>[];

    final page = await SparkDiagnostics.runWithSink(
      events.add,
      () => repository.search(
        const PaperSearchQuery(term: 'Milmer', limit: 20),
      ),
    );

    expect(page.source, PaperPageSource.seed);
    expect(page.papers.map((paper) => paper.id), contains('2502.00547'));
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCatalogArxivSearch],
    );
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

  test('findById refreshes an expired cached paper', () async {
    var now = DateTime.utc(2024, 3, 1);
    repository = OfflineFirstPaperCatalogRepository(
      remoteSource: remote,
      cacheStore: cache,
      seedRepository: const ArxivSeedRepository(),
      clock: () => now,
      cachePolicy: const PaperCachePolicy(
        detailTtl: Duration(hours: 1),
      ),
    );
    remote.detail = _paper('2401.00001', title: 'First title');
    await repository.findById('2401.00001');
    now = DateTime.utc(2024, 3, 1, 2);
    remote.detail = _paper('2401.00001', title: 'Updated title');

    final refreshed = await repository.findById('2401.00001');

    expect(refreshed?.title, 'Updated title');
    expect(remote.detailRequests, 2);
  });

  test('findById falls back to an expired cache when remote fails', () async {
    var now = DateTime.utc(2024, 3, 1);
    repository = OfflineFirstPaperCatalogRepository(
      remoteSource: remote,
      cacheStore: cache,
      seedRepository: const ArxivSeedRepository(),
      clock: () => now,
      cachePolicy: const PaperCachePolicy(
        detailTtl: Duration(hours: 1),
      ),
    );
    remote.detail = _paper('2401.00001', title: 'Cached title');
    await repository.findById('2401.00001');
    now = DateTime.utc(2024, 3, 1, 2);
    remote.error = StateError('offline');
    final events = <SparkDiagnosticEvent>[];

    final fallback = await SparkDiagnostics.runWithSink(
      events.add,
      () => repository.findById('2401.00001'),
    );

    expect(fallback?.title, 'Cached title');
    expect(remote.detailRequests, 2);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCatalogArxivFindById],
    );
  });

  test('cache read failures do not prevent a remote detail result', () async {
    final failingCache = _FailingPaperCacheStore(failReads: true);
    repository = OfflineFirstPaperCatalogRepository(
      remoteSource: remote,
      cacheStore: failingCache,
      seedRepository: const ArxivSeedRepository(),
    );
    remote.detail = _paper('2401.00001', title: 'Remote title');
    final events = <SparkDiagnosticEvent>[];

    final paper = await SparkDiagnostics.runWithSink(
      events.add,
      () => repository.findById('2401.00001'),
    );

    expect(paper?.title, 'Remote title');
    expect(remote.detailRequests, 1);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCatalogCacheReadPaper],
    );
  });

  test('cache write failures do not discard a remote detail result', () async {
    final failingCache = _FailingPaperCacheStore(failWrites: true);
    repository = OfflineFirstPaperCatalogRepository(
      remoteSource: remote,
      cacheStore: failingCache,
      seedRepository: const ArxivSeedRepository(),
    );
    remote.detail = _paper('2401.00001', title: 'Remote title');
    final events = <SparkDiagnosticEvent>[];

    final paper = await SparkDiagnostics.runWithSink(
      events.add,
      () => repository.findById('2401.00001'),
    );

    expect(paper?.title, 'Remote title');
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCatalogCacheWritePaper],
    );
  });

  test('cache write failures do not discard a remote feed result', () async {
    repository = OfflineFirstPaperCatalogRepository(
      remoteSource: remote,
      cacheStore: _FailingPaperCacheStore(failWrites: true),
      seedRepository: const ArxivSeedRepository(),
    );
    remote.feed = _page('2401.00001');
    final events = <SparkDiagnosticEvent>[];

    final page = await SparkDiagnostics.runWithSink(
      events.add,
      () => repository.loadFeed(
        const PaperFeedQuery(category: 'cs.AI', limit: 10),
      ),
    );

    expect(page.source, PaperPageSource.remote);
    expect(page.papers.single.id, '2401.00001');
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCatalogCacheWritePage],
    );
  });

  test('cache page read failures are reported before the seed fallback',
      () async {
    repository = OfflineFirstPaperCatalogRepository(
      remoteSource: remote,
      cacheStore: _FailingPaperCacheStore(failReads: true),
      seedRepository: const ArxivSeedRepository(),
    );
    remote.error = StateError('offline');
    final events = <SparkDiagnosticEvent>[];

    final page = await SparkDiagnostics.runWithSink(
      events.add,
      () => repository.loadFeed(const PaperFeedQuery(limit: 2)),
    );

    expect(page.source, PaperPageSource.seed);
    expect(
      events.map((event) => event.operation),
      [
        SparkDiagnosticOperation.paperCatalogArxivLoadFeed,
        SparkDiagnosticOperation.paperCatalogCacheReadPage,
      ],
    );
  });
}

class _FailingPaperCacheStore implements PaperCacheStore {
  _FailingPaperCacheStore({this.failReads = false, this.failWrites = false});

  final bool failReads;
  final bool failWrites;

  @override
  Future<CachedPaperPageRecord?> readPage(String queryKey) async {
    if (failReads) throw StateError('cache read failed');
    return null;
  }

  @override
  Future<PaperCacheRecord?> readPaper(String paperId) async {
    if (failReads) throw StateError('cache read failed');
    return null;
  }

  @override
  Future<void> writePage({
    required PaperPageCacheRecord page,
    required Iterable<PaperCacheRecord> papers,
  }) async {
    if (failWrites) throw StateError('cache write failed');
  }

  @override
  Future<void> writePaper(PaperCacheRecord paper) async {
    if (failWrites) throw StateError('cache write failed');
  }
}

class _FakeArxivSource implements ArxivCatalogSource {
  ArxivAtomPageDto? feed;
  ArxivAtomPaperDto? detail;
  Object? error;
  String? lastCategory;
  DateTime? lastPublishedFrom;
  DateTime? lastPublishedUntil;
  int detailRequests = 0;

  @override
  Future<ArxivAtomPageDto> loadLatest({
    String? category,
    DateTime? publishedFrom,
    DateTime? publishedUntil,
    required int offset,
    required int limit,
  }) async {
    lastCategory = category;
    lastPublishedFrom = publishedFrom;
    lastPublishedUntil = publishedUntil;
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

ArxivAtomPaperDto _paper(String id, {String title = 'Remote paper'}) {
  return ArxivAtomPaperDto(
    id: id,
    title: title,
    summary: 'A remote abstract.',
    authors: const ['Remote Author'],
    affiliations: const ['Spark Lab'],
    categories: const ['cs.AI'],
    primaryCategory: 'cs.AI',
    publishedAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 2),
    paperUrl: 'https://arxiv.org/abs/$id',
    pdfUrl: 'https://arxiv.org/pdf/$id',
  );
}
