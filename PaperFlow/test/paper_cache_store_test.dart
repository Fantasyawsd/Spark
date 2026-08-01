import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/core/storage/local_json_store.dart';
import 'package:paperflow/src/core/storage/versioned_local_json_store.dart';
import 'package:paperflow/src/features/papers/data/cache/file_paper_cache_store.dart';
import 'package:paperflow/src/features/papers/data/cache/paper_cache_mapper.dart';
import 'package:paperflow/src/features/papers/data/cache/paper_cache_record.dart';
import 'package:paperflow/src/features/papers/domain/paper.dart';

void main() {
  late Directory directory;
  late File file;
  late FilePaperCacheStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('paperflow-cache-');
    file = File('${directory.path}${Platform.pathSeparator}papers.json');
    store = FilePaperCacheStore(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('roundtrips a query page and independent domain paper fields', () async {
    final cachedAt = DateTime.utc(2024, 3, 1, 10);
    final mapper = const PaperCacheMapper();
    final record = mapper.toRecord(_paper(), cachedAt: cachedAt);
    const queryKey = 'feed|category=cs.AI|offset=0|limit=20';

    await store.writePage(
      page: PaperPageCacheRecord(
        queryKey: queryKey,
        paperIds: [record.id],
        fetchedAt: cachedAt.toIso8601String(),
        nextOffset: 20,
      ),
      papers: [record],
    );

    final restoredPage = await store.readPage(queryKey);
    final restoredPaper = mapper.toDomain(restoredPage!.papers.single);
    expect(restoredPage.page.nextOffset, 20);
    expect(restoredPage.page.fetchedAt, '2024-03-01T10:00:00.000Z');
    expect(restoredPaper.id, '2401.00001');
    expect(restoredPaper.content.originalAbstractMarkdown, r'Equation $x^2$.');
    expect(restoredPaper.relatedPapers.single.id, '2401.00002');
    expect(restoredPaper.metrics.citations, 12);
    expect(restoredPaper.publishedAt, DateTime.utc(2024, 1, 2));
    expect(mapper.cachedAt(restoredPage.papers.single), cachedAt);
  });

  test('writes and reads a paper without a query page', () async {
    final mapper = const PaperCacheMapper();
    final record = mapper.toRecord(
      _paper(),
      cachedAt: DateTime.utc(2024, 3, 1),
    );

    await store.writePaper(record);

    expect((await store.readPaper('2401.00001'))?.title, 'Cached paper');
    expect(await store.readPage('missing'), isNull);
  });

  test('quarantines malformed cache JSON instead of leaking records', () async {
    await file.writeAsString('{not-json');

    LocalDataCorruptionException? failure;
    try {
      await store.readPaper('2401.00001');
    } on LocalDataCorruptionException catch (error) {
      failure = error;
    }

    expect(failure, isNotNull);
    expect(failure!.backupPath, isNotNull);
    expect(await File(failure.backupPath!).readAsString(), '{not-json');
    expect(await file.exists(), isFalse);
  });

  test('quarantines structurally invalid cache payloads', () async {
    final envelopeStore = VersionedLocalJsonStore(
      LocalJsonStore(fileName: 'unused.json', file: file),
      schemaId: 'papers.catalog-cache',
    );
    await envelopeStore.writeMap({
      'papers': <String, dynamic>{},
      'pages': {
        'feed': {
          'queryKey': 'feed',
          'paperIds': ['missing'],
          'fetchedAt': '2024-01-01T00:00:00Z',
          'nextOffset': null,
        },
      },
    });

    await expectLater(
      store.readPage('feed'),
      throwsA(isA<LocalDataCorruptionException>()),
    );
  });
}

Paper _paper() {
  return Paper(
    id: '2401.00001',
    venue: 'ICLR 2024',
    title: 'Cached paper',
    authors: const ['Alice Smith', 'Bob Jones'],
    firstAffiliation: 'PaperFlow Lab',
    topics: const ['cs.AI', 'cs.LG'],
    abstractText: r'Equation $x^2$.',
    chineseAbstractMarkdown: '中文摘要。',
    relatedPapers: const [
      RelatedPaper(
        id: '2401.00002',
        title: 'Related',
        venue: 'arXiv',
        relation: '共同领域 cs.AI',
      ),
    ],
    readMinutes: 4,
    citations: 12,
    likes: 3,
    comments: 4,
    saves: 5,
    shares: 6,
    arxivId: '2401.00001',
    doi: '10.1000/cache',
    paperUrl: 'https://arxiv.org/abs/2401.00001',
    pdfUrl: 'https://arxiv.org/pdf/2401.00001',
    publishedAt: DateTime.utc(2024, 1, 2),
    updatedAt: DateTime.utc(2024, 2, 3),
    license: 'CC BY 4.0',
    source: 'arxiv',
  );
}
