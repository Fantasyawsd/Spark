import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../application/paper_keyword_service.dart';
import '../domain/paper_keyword_record.dart';
import 'paper_keyword_json_mapper.dart';

class FilePaperKeywordRepository implements PaperKeywordRepository {
  FilePaperKeywordRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_keywords.json'),
          schemaId: 'papers.keywords',
          validatePayload: PaperKeywordJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<PaperKeywordRecord?> load(String paperId) async {
    try {
      final json = await _store.readMap();
      if (json == null) return null;
      final value = json[paperId];
      if (value is! Map<String, dynamic>) return null;
      return PaperKeywordJsonMapper.fromJson(paperId, value);
    } catch (error) {
      throw PaperKeywordPersistenceException('无法读取关键词缓存。', error);
    }
  }

  @override
  Future<void> save(PaperKeywordRecord record) async {
    try {
      await _store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        json[record.paperId] = PaperKeywordJsonMapper.toJson(record);
        return json;
      });
    } catch (error) {
      throw PaperKeywordPersistenceException('无法保存关键词缓存。', error);
    }
  }

  @override
  Future<void> clear(String paperId) async {
    try {
      await _store.updateMap((json) {
        if (json == null) return null;
        json.remove(paperId);
        return json;
      });
    } catch (error) {
      throw PaperKeywordPersistenceException('无法清除关键词缓存。', error);
    }
  }
}
