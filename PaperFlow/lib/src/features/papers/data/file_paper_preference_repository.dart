import '../../../core/storage/local_json_store.dart';
import '../domain/paper_preference_repository.dart';

class FilePaperPreferenceRepository implements PaperPreferenceRepository {
  FilePaperPreferenceRepository({LocalJsonStore? store})
      : _store = store ?? LocalJsonStore(fileName: 'paper_preferences.json');

  final LocalJsonStore _store;

  @override
  Future<PaperPreferences> load() async {
    try {
      final json = await _store.read();
      if (json == null) return PaperPreferences();
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Preference data must be an object.');
      }
      final topics = json['extraTopics'];
      return PaperPreferences(
        extraTopics: topics is List
            ? topics.whereType<String>().toList(growable: false)
            : const [],
      );
    } catch (error) {
      throw PaperPreferencePersistenceException('无法读取论文偏好。', error);
    }
  }

  @override
  Future<void> save(PaperPreferences preferences) async {
    try {
      await _store.write({'extraTopics': preferences.extraTopics});
    } catch (error) {
      throw PaperPreferencePersistenceException('无法保存论文偏好。', error);
    }
  }
}
