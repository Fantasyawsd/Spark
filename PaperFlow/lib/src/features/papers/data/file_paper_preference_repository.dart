import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_preference_repository.dart';
import 'paper_preference_json_mapper.dart';

class FilePaperPreferenceRepository implements PaperPreferenceRepository {
  FilePaperPreferenceRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_preferences.json'),
          schemaId: 'papers.preferences',
          validatePayload: PaperPreferenceJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<PaperPreferences> load() async {
    try {
      final json = await _store.readMap();
      if (json == null) return PaperPreferences();
      return PaperPreferenceJsonMapper.fromJson(json);
    } catch (error) {
      throw PaperPreferencePersistenceException('无法读取论文偏好。', error);
    }
  }

  @override
  Future<void> save(PaperPreferences preferences) async {
    try {
      await _store.writeMap(PaperPreferenceJsonMapper.toJson(preferences));
    } catch (error) {
      throw PaperPreferencePersistenceException('无法保存论文偏好。', error);
    }
  }
}
