import '../domain/paper.dart';
import '../domain/paper_link_service.dart';
import '../domain/paper_pdf.dart';
import '../domain/paper_pdf_content_provider.dart';
import '../domain/paper_pdf_repository.dart';
import 'paper_pdf_extraction_service.dart';

final class CachedPaperPdfContentProvider implements PaperPdfContentProvider {
  const CachedPaperPdfContentProvider({
    required this.repository,
    required this.extractionService,
  });

  final PaperPdfRepository repository;
  final PaperPdfExtractionService extractionService;

  @override
  Future<PaperPdfExtract> load(Paper paper) async {
    final pdfUrl = validPaperUri(paper.pdfUrl);
    if (pdfUrl == null) {
      throw const PaperPdfException('该论文没有可用的 PDF 链接。');
    }
    final version = paperPdfCacheVersion(
      pdfUrl,
      sourceUpdatedAt: paper.updatedAt ?? paper.publishedAt,
    );
    PaperPdfExtract? cached;
    try {
      cached = await repository.load(paper.id, version);
    } catch (_) {
      cached = null;
    }
    if (cached != null &&
        cached.paperId == paper.id &&
        cached.version == version) {
      return cached;
    }

    final bytes = await extractionService.download(pdfUrl);
    final extract = await extractionService.extract(
      paperId: paper.id,
      version: version,
      bytes: bytes,
    );
    try {
      await repository.save(extract);
    } catch (_) {
      // PDF extraction remains usable when the optional cache cannot persist.
    }
    return extract;
  }
}
