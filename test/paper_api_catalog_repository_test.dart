import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/papers/data/paper_api_catalog_repository.dart';
import 'package:spark/src/features/papers/data/providers/paper_api/paper_api_client.dart';
import 'package:spark/src/features/papers/data/providers/paper_api/paper_api_dto.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';

void main() {
  late _FakePaperApiSource source;
  late _FallbackCatalogRepository fallback;
  late PaperApiCatalogRepository repository;

  setUp(() {
    source = _FakePaperApiSource();
    fallback = _FallbackCatalogRepository();
    repository = PaperApiCatalogRepository(
      remoteSource: source,
      fallbackRepository: fallback,
      clock: () => DateTime.utc(2026, 8, 11, 12),
    );
  });

  test(
    'maps API data without combining independent citation sources',
    () async {
      source.page = PaperApiPageDto(
        channel: 'latest',
        items: [_paperDto()],
        nextCursor: 'next-page',
      );

      final page = await repository.loadFeed(const PaperFeedQuery(limit: 10));
      final paper = page.papers.single;

      expect(page.source, PaperPageSource.paperApi);
      expect(page.nextCursor, 'next-page');
      expect(page.nextOffset, 1);
      expect(paper.id, 'paper_fixture');
      expect(paper.title, 'Fixture AI Paper');
      expect(paper.metrics.citations, 4);
      expect(paper.venue, isNull);
      expect(paper.paperUrl, 'https://arxiv.org/abs/2401.99999');
      expect(fallback.loadFeedCalls, 0);
    },
  );

  test(
    'a valid empty API page remains empty instead of using unrelated data',
    () async {
      source.page = const PaperApiPageDto(
        channel: 'latest',
        items: [],
        nextCursor: null,
      );

      final page = await repository.loadFeed(const PaperFeedQuery());

      expect(page.papers, isEmpty);
      expect(page.source, PaperPageSource.paperApi);
      expect(fallback.loadFeedCalls, 0);
    },
  );

  test(
    'API failures retain the existing catalog fallback and explain it',
    () async {
      source.error = const PaperApiException(
        PaperApiErrorKind.network,
        'offline',
      );
      fallback.page = PaperPage(
        papers: [_fallbackPaper],
        source: PaperPageSource.remote,
        nextOffset: 20,
      );
      final events = <SparkDiagnosticEvent>[];

      final page = await SparkDiagnostics.runWithSink(
        events.add,
        () => repository.loadFeed(const PaperFeedQuery()),
      );

      expect(page.papers.single.id, _fallbackPaper.id);
      expect(page.source, PaperPageSource.remote);
      expect(page.nextOffset, 20);
      expect(page.error?.kind, PaperCatalogErrorKind.network);
      expect(page.error?.message, contains('Paper API'));
      expect(fallback.loadFeedCalls, 1);
      expect(
        events.map((event) => event.operation),
        [SparkDiagnosticOperation.paperCatalogApiLoadFeed],
      );
    },
  );

  test('API detail failures are reported once before catalog fallback',
      () async {
    source.error = StateError('private-api-response');
    final events = <SparkDiagnosticEvent>[];

    final detail = await SparkDiagnostics.runWithSink(
      events.add,
      () => repository.findById(_fallbackPaper.id),
    );

    expect(detail?.id, _fallbackPaper.id);
    expect(fallback.findByIdCalls, 1);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCatalogApiFindById],
    );
    expect(events.single.summary, isNot(contains('private-api-response')));
  });

  test(
    'search remains on the existing catalog and missing details fall back',
    () async {
      source.detail = null;

      final search = await repository.search(
        const PaperSearchQuery(term: 'fixture'),
      );
      final detail = await repository.findById(_fallbackPaper.id);

      expect(search.papers.single.id, _fallbackPaper.id);
      expect(detail?.id, _fallbackPaper.id);
      expect(fallback.searchCalls, 1);
      expect(fallback.findByIdCalls, 1);
    },
  );
}

final class _FakePaperApiSource implements PaperApiSource {
  PaperApiPageDto? page;
  PaperApiPaperDto? detail;
  Object? error;

  @override
  Future<PaperApiPaperDto?> findById(String paperId) async {
    final failure = error;
    if (failure != null) throw failure;
    return detail;
  }

  @override
  Future<PaperApiPageDto> loadFeed(PaperFeedQuery query) async {
    final failure = error;
    if (failure != null) throw failure;
    return page!;
  }
}

final class _FallbackCatalogRepository implements PaperCatalogRepository {
  PaperPage page = PaperPage(
    papers: [_fallbackPaper],
    source: PaperPageSource.seed,
  );
  int loadFeedCalls = 0;
  int searchCalls = 0;
  int findByIdCalls = 0;

  @override
  Future<Paper?> findById(String paperId) async {
    findByIdCalls++;
    return paperId == _fallbackPaper.id ? _fallbackPaper : null;
  }

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    loadFeedCalls++;
    return page;
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async {
    searchCalls++;
    return page;
  }
}

PaperApiPaperDto _paperDto() => PaperApiPaperDto(
      paperId: 'paper_fixture',
      title: 'Fixture AI Paper',
      abstractText: 'A deterministic fixture.',
      authors: const ['Ada Lovelace'],
      publishedAt: DateTime.utc(2026, 8, 11),
      updatedAt: null,
      subjects: const ['cs.AI'],
      externalIds: const {'arxiv_id': '2401.99999'},
      discoverySources: const ['arxiv'],
      signals: const {
        'openalex': {'citation_count': 4},
        'semantic_scholar': {'citation_count': 7},
      },
      metadata: const {},
    );

final _fallbackPaper = Paper(
  id: 'fallback-paper',
  title: 'Fallback paper',
  authors: const ['Grace Hopper'],
  abstractText: 'Fallback abstract',
  chineseAbstractMarkdown: '尚未生成。',
  readMinutes: 1,
);
