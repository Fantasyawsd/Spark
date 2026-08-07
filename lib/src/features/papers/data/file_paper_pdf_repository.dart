import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_pdf.dart';
import '../domain/paper_pdf_repository.dart';
import 'cache/paper_record_cache_policy.dart';
import 'paper_pdf_json_mapper.dart';

const paperPdfDefaultCachePolicy = PaperRecordCachePolicy(
  ttl: Duration(days: 30),
  maxEntries: 32,
);

/// 论文 PDF 提取结果的 JSON 持久化：每个论文按版本保存一份。
class FilePaperPdfRepository implements PaperPdfRepository {
  FilePaperPdfRepository({
    LocalJsonStore? store,
    DateTime Function()? clock,
    PaperRecordCachePolicy policy = paperPdfDefaultCachePolicy,
  })  : _clock = clock ?? DateTime.now,
        _policy = _validatedPolicy(policy),
        _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_pdf_extracts.json'),
          schemaId: 'papers.pdf-extracts',
          schemaVersion: 2,
          migrations: const {1: _discardLegacyExtracts},
          validatePayload: PaperPdfJsonMapper.validatePayload,
        );

  static Object? _discardLegacyExtracts(Object? _) {
    return <String, dynamic>{};
  }

  final VersionedLocalJsonStore _store;
  final DateTime Function() _clock;
  final PaperRecordCachePolicy _policy;

  static PaperRecordCachePolicy _validatedPolicy(
    PaperRecordCachePolicy policy,
  ) {
    policy.validate();
    return policy;
  }

  @override
  Future<PaperPdfExtract?> load(String paperId, String version) async {
    try {
      final json = await _store.readMap();
      if (json == null) return null;
      final value = json[paperId];
      if (value is! Map<String, dynamic>) return null;
      final extract = PaperPdfJsonMapper.fromJson(paperId, value);
      if (extract.version != version) return null;
      if (extract.chunks.isEmpty) {
        throw const FormatException('PDF 提取缓存没有正文分块。');
      }
      return _policy.isExpired(extract.extractedAt, _clock()) ? null : extract;
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
        return retainNewestPaperRecords(
          json,
          now: _clock(),
          policy: _policy,
          timestampOf: (paperId, value) =>
              PaperPdfJsonMapper.fromJson(paperId, value).extractedAt,
        );
      });
    } catch (error) {
      throw PaperPdfPersistenceException('无法保存 PDF 提取缓存。', error);
    }
  }
}
