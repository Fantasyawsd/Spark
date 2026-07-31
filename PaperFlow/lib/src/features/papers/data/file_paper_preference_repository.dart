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
        positions: _intMap(json['positions']),
        primaryCategoryIndex: json['primaryCategoryIndex'] as int? ?? 0,
        topicIndex: json['topicIndex'] as int? ?? 0,
      );
    } catch (error) {
      throw PaperPreferencePersistenceException('无法读取论文偏好。', error);
    }
  }

  @override
  Future<void> save(PaperPreferences preferences) async {
    try {
      await _store.write({
        'extraTopics': preferences.extraTopics,
        'positions': preferences.positions,
        'primaryCategoryIndex': preferences.primaryCategoryIndex,
        'topicIndex': preferences.topicIndex,
      });
    } catch (error) {
      throw PaperPreferencePersistenceException('无法保存论文偏好。', error);
    }
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is int)
          entry.key as String: entry.value as int,
    };
  }
}
