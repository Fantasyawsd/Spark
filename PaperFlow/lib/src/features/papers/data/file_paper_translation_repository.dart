import '../../../core/storage/local_json_store.dart';
import '../application/paper_translation_service.dart';

class FilePaperTranslationRepository implements PaperTranslationRepository {
  FilePaperTranslationRepository({LocalJsonStore? store})
      : _store = store ?? LocalJsonStore(fileName: 'paper_translations.json');

  final LocalJsonStore _store;

  @override
  Future<String?> load(String paperId) async {
    try {
      final json = await _store.read();
      if (json is! Map<String, dynamic>) return null;
      final value = json[paperId];
      return value is String && value.trim().isNotEmpty ? value : null;
    } catch (error) {
      throw PaperTranslationPersistenceException('无法读取中文翻译。', error);
    }
  }

  @override
  Future<void> save(String paperId, String markdown) async {
    try {
      final current = await _store.read();
      final json = current is Map<String, dynamic>
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};
      json[paperId] = markdown;
      await _store.write(json);
    } catch (error) {
      throw PaperTranslationPersistenceException('无法保存中文翻译。', error);
    }
  }

  @override
  Future<void> clear(String paperId) async {
    try {
      final current = await _store.read();
      if (current is! Map<String, dynamic>) return;
      final json = Map<String, dynamic>.from(current)..remove(paperId);
      await _store.write(json);
    } catch (error) {
      throw PaperTranslationPersistenceException('无法清除中文翻译。', error);
    }
  }
}
