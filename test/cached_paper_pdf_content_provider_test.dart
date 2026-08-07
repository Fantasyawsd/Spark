import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/data/cached_paper_pdf_content_provider.dart';
import 'package:spark/src/features/papers/data/paper_pdf_extraction_service.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_pdf.dart';
import 'package:spark/src/features/papers/domain/paper_pdf_repository.dart';

void main() {
  test('returns a matching cached extract without downloading', () async {
    final cached = _extract(
      paperPdfCacheVersion(
        Uri.parse(_paper.pdfUrl!),
        sourceUpdatedAt: _paper.updatedAt,
      ),
    );
    final repository = _PdfRepository(cached);
    final extractionService = _FakeExtractionService();
    final provider = CachedPaperPdfContentProvider(
      repository: repository,
      extractionService: extractionService,
    );

    final result = await provider.load(_paper);

    expect(result, same(cached));
    expect(extractionService.downloadCalls, 0);
    expect(repository.saved, isNull);
  });

  test('downloads, extracts and saves a cache miss', () async {
    final repository = _PdfRepository(null);
    final extractionService = _FakeExtractionService();
    final provider = CachedPaperPdfContentProvider(
      repository: repository,
      extractionService: extractionService,
    );

    final result = await provider.load(_paper);

    expect(extractionService.downloadCalls, 1);
    expect(extractionService.extractCalls, 1);
    expect(repository.saved, same(result));
    expect(result.version, contains('extractor='));
  });

  test('cache read failures fall back to downloading', () async {
    final repository = _PdfRepository(null, failLoad: true);
    final extractionService = _FakeExtractionService();
    final provider = CachedPaperPdfContentProvider(
      repository: repository,
      extractionService: extractionService,
    );

    final result = await provider.load(_paper);

    expect(result.chunks.single.text, 'body');
    expect(extractionService.downloadCalls, 1);
    expect(repository.saved, same(result));
  });

  test('cache save failures do not discard extracted text', () async {
    final repository = _PdfRepository(null, failSave: true);
    final extractionService = _FakeExtractionService();
    final provider = CachedPaperPdfContentProvider(
      repository: repository,
      extractionService: extractionService,
    );

    final result = await provider.load(_paper);

    expect(result.chunks.single.text, 'body');
    expect(extractionService.extractCalls, 1);
  });
}

final _paper = Paper(
  id: 'paper-1',
  title: 'Paper title',
  authors: const ['Author'],
  abstractText: 'Abstract',
  chineseAbstractMarkdown: '',
  readMinutes: 3,
  pdfUrl: 'https://example.test/paper.pdf',
  updatedAt: DateTime.utc(2026, 8, 7),
);

PaperPdfExtract _extract(String version) => PaperPdfExtract(
      paperId: _paper.id,
      version: version,
      chunks: const [PaperPdfChunk(index: 0, text: 'body')],
      extractedAt: DateTime.utc(2026, 8, 7),
    );

class _PdfRepository implements PaperPdfRepository {
  _PdfRepository(
    this.cached, {
    this.failLoad = false,
    this.failSave = false,
  });

  final PaperPdfExtract? cached;
  final bool failLoad;
  final bool failSave;
  PaperPdfExtract? saved;

  @override
  Future<PaperPdfExtract?> load(String paperId, String version) async {
    if (failLoad) throw StateError('simulated cache read failure');
    return cached;
  }

  @override
  Future<void> save(PaperPdfExtract extract) async {
    if (failSave) throw StateError('simulated cache save failure');
    saved = extract;
  }
}

class _FakeExtractionService extends PaperPdfExtractionService {
  var downloadCalls = 0;
  var extractCalls = 0;

  @override
  Future<List<int>> download(Uri url) async {
    downloadCalls++;
    return const [0x25, 0x50, 0x44, 0x46, 0x2d];
  }

  @override
  Future<PaperPdfExtract> extract({
    required String paperId,
    required String version,
    required List<int> bytes,
    int targetCharsPerChunk = paperPdfDefaultTargetCharsPerChunk,
  }) async {
    extractCalls++;
    return PaperPdfExtract(
      paperId: paperId,
      version: version,
      chunks: const [PaperPdfChunk(index: 0, text: 'body')],
      extractedAt: DateTime.utc(2026, 8, 7),
    );
  }
}
