import '../domain/paper_pdf.dart';
import '../domain/paper_pdf_repository.dart';

/// 内存实现：用于预览、测试与未装配持久化的环境。
class InMemoryPaperPdfRepository implements PaperPdfRepository {
  final Map<String, PaperPdfExtract> _store = {};

  @override
  Future<PaperPdfExtract?> load(String paperId, String version) async {
    final extract = _store[paperId];
    if (extract == null || extract.version != version) return null;
    return extract;
  }

  @override
  Future<void> save(PaperPdfExtract extract) async {
    _store[extract.paperId] = extract;
  }
}
