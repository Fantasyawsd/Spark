import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/core/storage/versioned_local_json_store.dart';
import 'package:spark/src/features/papers/application/paper_pdf_context_builder.dart';
import 'package:spark/src/features/papers/data/cache/paper_record_cache_policy.dart';
import 'package:spark/src/features/papers/data/file_paper_pdf_repository.dart';
import 'package:spark/src/features/papers/data/paper_pdf_extraction_service.dart';
import 'package:spark/src/features/papers/domain/paper_pdf.dart';
import 'package:spark/src/features/papers/domain/paper_pdf_repository.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('PaperPdfExtractionService', () {
    test('extracts text and chunks multi-page PDFs with page labels', () async {
      final bytes = await _buildPdf(pages: 2);
      final service = PaperPdfExtractionService();

      final extract = await service.extract(
        paperId: 'paper-1',
        version: 'v1',
        bytes: bytes,
      );

      expect(extract.chunks, isNotEmpty);
      final allText = extract.chunks.map((c) => c.text).join('\n');
      expect(allText, contains('Page 1 content'));
      expect(allText, contains('Page 2 content'));
      expect(extract.chunks.first.pageNumber, 1);
    });

    test('chunks respect the target size budget', () async {
      final bytes = await _buildPdf(pages: 3);
      final service = PaperPdfExtractionService();

      final extract = await service.extract(
        paperId: 'paper-1',
        version: 'v1',
        bytes: bytes,
        targetCharsPerChunk: 120,
      );

      expect(extract.chunks.length, greaterThan(1));
      for (final chunk in extract.chunks) {
        expect(chunk.charCount, lessThanOrEqualTo(260));
      }
    });

    test('splits a single paragraph without exceeding the target budget',
        () async {
      final bytes = await _buildPdf(pages: 1);
      final service = PaperPdfExtractionService();

      final extract = await service.extract(
        paperId: 'paper-1',
        version: 'v1',
        bytes: bytes,
        targetCharsPerChunk: 10,
      );

      expect(extract.chunks.length, greaterThan(1));
      expect(
        extract.chunks.every((chunk) => chunk.charCount <= 10),
        isTrue,
      );
      final text = extract.chunks.map((chunk) => chunk.text).join(' ');
      expect(text, contains('Page'));
      expect(text, contains('content'));
      expect(text, contains('extract'));
    });

    test('rejects non-PDF bytes as invalid', () async {
      final service = PaperPdfExtractionService();
      expect(
        () => service.extract(
          paperId: 'paper-1',
          version: 'v1',
          bytes: [0, 1, 2, 3, 4, 5],
        ),
        throwsA(isA<PaperPdfException>()),
      );
    });

    test('accepts the input byte boundary and rejects one byte below it',
        () async {
      final bytes = await _buildPdf(pages: 1);
      final boundaryService = PaperPdfExtractionService(
        maxInputBytes: bytes.length,
      );
      final rejectingService = PaperPdfExtractionService(
        maxInputBytes: bytes.length - 1,
      );

      expect(
        (await boundaryService.extract(
          paperId: 'paper-1',
          version: 'v1',
          bytes: bytes,
        ))
            .chunks,
        isNotEmpty,
      );
      expect(
        () => rejectingService.extract(
          paperId: 'paper-1',
          version: 'v1',
          bytes: bytes,
        ),
        throwsA(isA<PaperPdfException>()),
      );
    });

    test('accepts the page limit boundary and rejects an extra page', () async {
      final onePage = await _buildPdf(pages: 1);
      final twoPages = await _buildPdf(pages: 2);
      final service = PaperPdfExtractionService(maxPages: 1);

      expect(
        (await service.extract(
          paperId: 'paper-1',
          version: 'v1',
          bytes: onePage,
        ))
            .chunks,
        isNotEmpty,
      );
      await expectLater(
        service.extract(
          paperId: 'paper-2',
          version: 'v1',
          bytes: twoPages,
        ),
        throwsA(isA<PaperPdfException>()),
      );
    });

    test('rejects extracted text above the configured character limit',
        () async {
      final bytes = await _buildPdf(pages: 1);
      final baseline = await PaperPdfExtractionService().extract(
        paperId: 'baseline',
        version: 'v1',
        bytes: bytes,
      );
      final boundaryService = PaperPdfExtractionService(
        maxExtractedChars: baseline.charCount,
      );
      final rejectingService = PaperPdfExtractionService(
        maxExtractedChars: baseline.charCount - 1,
      );

      expect(
        (await boundaryService.extract(
          paperId: 'paper-1',
          version: 'v1',
          bytes: bytes,
        ))
            .charCount,
        baseline.charCount,
      );
      await expectLater(
        rejectingService.extract(
          paperId: 'paper-2',
          version: 'v1',
          bytes: bytes,
        ),
        throwsA(isA<PaperPdfException>()),
      );
    });

    test('rejects output above the configured chunk limit', () async {
      final bytes = await _buildPdf(pages: 1);
      final baseline = await PaperPdfExtractionService().extract(
        paperId: 'baseline',
        version: 'v1',
        bytes: bytes,
        targetCharsPerChunk: 8,
      );
      final boundaryService = PaperPdfExtractionService(
        maxChunks: baseline.chunks.length,
      );
      final rejectingService = PaperPdfExtractionService(
        maxChunks: baseline.chunks.length - 1,
      );

      expect(
        (await boundaryService.extract(
          paperId: 'paper-1',
          version: 'v1',
          bytes: bytes,
          targetCharsPerChunk: 8,
        ))
            .chunks,
        hasLength(baseline.chunks.length),
      );
      await expectLater(
        rejectingService.extract(
          paperId: 'paper-2',
          version: 'v1',
          bytes: bytes,
          targetCharsPerChunk: 8,
        ),
        throwsA(isA<PaperPdfException>()),
      );
    });

    test('terminates extraction when its deadline expires', () async {
      final bytes = await _buildPdf(pages: 20);
      final service = PaperPdfExtractionService(
        extractionTimeout: const Duration(microseconds: 1),
      );

      await expectLater(
        service
            .extract(
              paperId: 'paper-1',
              version: 'v1',
              bytes: bytes,
            )
            .timeout(const Duration(seconds: 1)),
        throwsA(isA<PaperPdfException>()),
      );
    });

    test('cache version changes with source revision and extraction format',
        () {
      final url = Uri.parse('https://arxiv.org/pdf/2401.00001');

      final first = paperPdfCacheVersion(
        url,
        sourceUpdatedAt: DateTime.utc(2024, 1, 1),
      );
      final second = paperPdfCacheVersion(
        url,
        sourceUpdatedAt: DateTime.utc(2024, 1, 2),
      );

      expect(first, isNot(second));
      expect(first, contains('extractor=$paperPdfExtractionVersion'));
    });

    test('rejects a declared PDF size above the configured limit', () async {
      final client = _StreamingClient(
        chunks: const [
          <int>[0x25, 0x50, 0x44, 0x46, 0x2d]
        ],
        contentLength: 100,
      );
      final service = PaperPdfExtractionService(
        client: client,
        maxDownloadBytes: 10,
      );

      await expectLater(
        service.download(Uri.parse('https://example.test/paper.pdf')),
        throwsA(isA<PaperPdfException>()),
      );
      expect(client.closed, isFalse);
      expect(client.streamCancelled, isTrue);
    });

    test('rejects a chunked PDF once streamed bytes exceed the limit',
        () async {
      final client = _StreamingClient(
        chunks: const [
          <int>[0x25, 0x50, 0x44, 0x46, 0x2d],
          <int>[1, 2, 3, 4, 5, 6],
        ],
      );
      final service = PaperPdfExtractionService(
        client: client,
        maxDownloadBytes: 10,
      );

      await expectLater(
        service.download(Uri.parse('https://example.test/paper.pdf')),
        throwsA(isA<PaperPdfException>()),
      );
    });

    test('enforces a total timeout for a continuously streaming PDF', () async {
      final client = _PeriodicStreamingClient();
      addTearDown(client.close);
      final service = PaperPdfExtractionService(
        client: client,
        maxDownloadBytes: 1024 * 1024,
        downloadTimeout: const Duration(milliseconds: 30),
      );

      await expectLater(
        service
            .download(Uri.parse('https://example.test/paper.pdf'))
            .timeout(const Duration(milliseconds: 500)),
        throwsA(isA<PaperPdfException>()),
      );
      expect(client.streamCancelled, isTrue);
    });
  });

  test('malformed cached PDF chunks are quarantined', () async {
    final directory = await Directory.systemTemp.createTemp('spark-pdf-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}pdf.json');
    final envelopeStore = VersionedLocalJsonStore(
      LocalJsonStore(fileName: 'unused.json', file: file),
      schemaId: 'papers.pdf-extracts',
      schemaVersion: 2,
    );
    await envelopeStore.writeMap({
      'paper-1': {
        'version': 'v1',
        'extractedAt': '2026-08-07T00:00:00Z',
        'chunks': [
          {'index': 0, 'text': ''},
        ],
      },
    });
    final repository = FilePaperPdfRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    await expectLater(
      repository.load('paper-1', 'v1'),
      throwsA(isA<PaperPdfPersistenceException>()),
    );

    expect(await file.exists(), isFalse);
    expect(
      directory
          .listSync()
          .whereType<File>()
          .any((item) => item.path.contains('.corrupt.')),
      isTrue,
    );
  });

  group('FilePaperPdfRepository cache bounds', () {
    late Directory directory;
    late File file;
    late DateTime now;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('spark-pdf-bounds-');
      file = File('${directory.path}${Platform.pathSeparator}pdf.json');
      now = DateTime.utc(2026, 8, 7, 12);
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    FilePaperPdfRepository repository({int maxEntries = 2}) {
      return FilePaperPdfRepository(
        store: LocalJsonStore(fileName: 'unused.json', file: file),
        clock: () => now,
        policy: PaperRecordCachePolicy(
          ttl: const Duration(days: 1),
          maxEntries: maxEntries,
        ),
      );
    }

    test('load rejects a record after its TTL', () async {
      final cache = repository();
      await cache.save(_pdfExtract('paper-1', extractedAt: now));

      now = now.add(const Duration(days: 1, microseconds: 1));

      expect(await cache.load('paper-1', 'v1'), isNull);
    });

    test('save removes expired records and retains newest entries', () async {
      final cache = repository();
      await cache.save(
        _pdfExtract(
          'expired',
          extractedAt: now.subtract(const Duration(days: 2)),
        ),
      );
      await cache.save(
        _pdfExtract('oldest',
            extractedAt: now.subtract(const Duration(hours: 2))),
      );
      await cache.save(
        _pdfExtract('middle',
            extractedAt: now.subtract(const Duration(hours: 1))),
      );
      await cache.save(_pdfExtract('newest', extractedAt: now));

      final envelope = jsonDecode(await file.readAsString()) as Map;
      final payload = envelope['payload'] as Map;
      expect(payload.keys, containsAll(<String>['middle', 'newest']));
      expect(payload, isNot(contains('expired')));
      expect(payload, isNot(contains('oldest')));
      expect(payload, hasLength(2));
    });

    test('concurrent saves from separate repositories do not overwrite',
        () async {
      final first = repository(maxEntries: 10);
      final second = repository(maxEntries: 10);

      await Future.wait([
        first.save(_pdfExtract('paper-1', extractedAt: now)),
        second.save(_pdfExtract('paper-2', extractedAt: now)),
      ]);

      expect(await first.load('paper-1', 'v1'), isNotNull);
      expect(await first.load('paper-2', 'v1'), isNotNull);
    });
  });

  group('PaperPdfContextBuilder', () {
    test('builds traceable chunks with page labels', () {
      const chunks = [
        PaperPdfChunk(index: 0, text: '引言内容', pageNumber: 1),
        PaperPdfChunk(index: 1, text: '方法内容', pageNumber: 2),
      ];

      final context = PaperPdfContextBuilder.buildContextChunk(chunks);

      expect(context, contains('【第 1 页】'));
      expect(context, contains('【第 2 页】'));
      expect(context, contains('引言内容'));
      expect(context, contains('方法内容'));
    });

    test('respects the character budget and drops later chunks', () {
      final chunks = [
        for (var i = 0; i < 10; i++)
          PaperPdfChunk(index: i, text: 'x' * 1000, pageNumber: i + 1),
      ];

      final context =
          PaperPdfContextBuilder.buildContextChunk(chunks, maxChars: 1200);

      expect(context, contains('【第 1 页】'));
      expect(context, isNot(contains('【第 9 页】')));
    });
  });
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient({required this.chunks, this.contentLength});

  final List<List<int>> chunks;
  final int? contentLength;
  bool closed = false;
  bool streamCancelled = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        for (final chunk in chunks) {
          controller.add(chunk);
        }
        unawaited(controller.close());
      },
      onCancel: () {
        streamCancelled = true;
      },
    );
    return http.StreamedResponse(
      controller.stream,
      200,
      contentLength: contentLength,
      headers: const {'content-type': 'application/pdf'},
    );
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _PeriodicStreamingClient extends http.BaseClient {
  StreamController<List<int>>? _controller;
  Timer? _timer;
  bool streamCancelled = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        controller.add(const [0x25, 0x50, 0x44, 0x46, 0x2d]);
        _timer = Timer.periodic(
          const Duration(milliseconds: 5),
          (_) => controller.add(const [0]),
        );
      },
      onCancel: () {
        streamCancelled = true;
        _timer?.cancel();
      },
    );
    _controller = controller;
    return http.StreamedResponse(controller.stream, 200);
  }

  @override
  void close() {
    _timer?.cancel();
    unawaited(_controller?.close());
    super.close();
  }
}

Future<Uint8List> _buildPdf({required int pages}) async {
  final writer = PdfDocument();
  for (var pageNumber = 1; pageNumber <= pages; pageNumber++) {
    final page = writer.pages.add();
    page.graphics.drawString(
      'Page $pageNumber content with enough words to extract.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );
  }
  final bytes = await writer.save();
  writer.dispose();
  return Uint8List.fromList(bytes);
}

PaperPdfExtract _pdfExtract(String paperId, {required DateTime extractedAt}) {
  return PaperPdfExtract(
    paperId: paperId,
    version: 'v1',
    chunks: const [PaperPdfChunk(index: 0, text: 'cached text')],
    extractedAt: extractedAt,
  );
}
