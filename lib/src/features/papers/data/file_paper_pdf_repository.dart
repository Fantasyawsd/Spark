import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_pdf.dart';
import '../domain/paper_pdf_repository.dart';
import 'paper_pdf_json_mapper.dart';

/// 论文 PDF 提取结果的 JSON 持久化：每个论文按版本保存一份。
class FilePaperPdfRepository implements PaperPdfRepository {
  FilePaperPdfRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_pdf_extracts.json'),
          schemaId: 'papers.pdf-extracts',
          validatePayload: PaperPdfJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<PaperPdfExtract?> load(String paperId, String version) async {
    try {
      final json = await _store.readMap();
      if (json == null) return null;
      final value = json[paperId];
      if (value is! Map<String, dynamic>) return null;
      final extract = PaperPdfJsonMapper.fromJson(paperId, value);
      if (extract.version != version) return null;
      return extract;
    } catch (error) {
      throw PaperPdfPersistenceException('无法读取 PDF 提取缓存。', error);
    }
  }

  @override
  Future<void> save(PaperPdfExtract extract) async {
    try {
      await _store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        json[extract.paperId] = PaperPdfJsonMapper.toJson(extract);
        return json;
      });
    } catch (error) {
      throw PaperPdfPersistenceException('无法保存 PDF 提取缓存。', error);
    }
  }
}
