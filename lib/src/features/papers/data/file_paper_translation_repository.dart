import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../application/paper_translation_service.dart';
import 'paper_translation_json_mapper.dart';

class FilePaperTranslationRepository implements PaperTranslationRepository {
  FilePaperTranslationRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_translations.json'),
          schemaId: 'papers.translations',
          validatePayload: PaperTranslationJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<String?> load(String paperId) async {
    try {
      final json = await _store.readMap();
      if (json == null) return null;
      final value = PaperTranslationJsonMapper.fromJson(json)[paperId];
      return value is String && value.trim().isNotEmpty ? value : null;
    } catch (error) {
      throw PaperTranslationPersistenceException('无法读取中文翻译。', error);
    }
  }

  @override
  Future<void> save(String paperId, String markdown) async {
    try {
      await _store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        json[paperId] = markdown;
        return json;
      });
    } catch (error) {
      throw PaperTranslationPersistenceException('无法保存中文翻译。', error);
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
      throw PaperTranslationPersistenceException('无法清除中文翻译。', error);
    }
  }
}
