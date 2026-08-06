import 'paper_pdf.dart';

/// 论文 PDF 提取结果的本地缓存：键为 paperId + PDF 版本。
abstract interface class PaperPdfRepository {
  Future<PaperPdfExtract?> load(String paperId, String version);

  Future<void> save(PaperPdfExtract extract);
}

class PaperPdfPersistenceException implements Exception {
  const PaperPdfPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
