import '../../../core/storage/local_json_store.dart';
import '../domain/paper_preference_repository.dart';
import 'paper_file_persistence.dart';
import 'paper_preference_json_mapper.dart';

class FilePaperPreferenceRepository implements PaperPreferenceRepository {
  FilePaperPreferenceRepository({LocalJsonStore? store})
      : _persistence = PaperFilePersistence(
          fileName: 'paper_preferences.json',
          schemaId: 'papers.preferences',
          schemaVersion: 2,
          migrations: const {1: _migrateV1ToV2},
          validatePayload: PaperPreferenceJsonMapper.validatePayload,
          store: store,
        );

  static Object? _migrateV1ToV2(Object? payload) {
    if (payload is! Map<String, dynamic>) return payload;
    return Map<String, dynamic>.from(payload)..['timeRanges'] = const {};
  }

  final PaperFilePersistence _persistence;

  @override
  Future<PaperPreferences> load() {
    return _persistence.guard(() async {
      final json = await _persistence.store.readMap();
      if (json == null) return PaperPreferences();
      return PaperPreferenceJsonMapper.fromJson(json);
    }, (error) => PaperPreferencePersistenceException('无法读取论文偏好。', error));
  }

  @override
  Future<void> save(PaperPreferences preferences) {
    return _persistence.guard(
      () => _persistence.store.writeMap(
        PaperPreferenceJsonMapper.toJson(preferences),
      ),
      (error) => PaperPreferencePersistenceException('无法保存论文偏好。', error),
    );
  }
}
