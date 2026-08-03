import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_channel_preference_repository.dart';
import 'paper_channel_preference_json_mapper.dart';

class FilePaperChannelPreferenceRepository
    implements PaperChannelPreferenceRepository {
  FilePaperChannelPreferenceRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_channel_preferences.json'),
          schemaId: 'papers.channel-preferences',
          validatePayload: PaperChannelPreferenceJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<PaperChannelPreferences> load() async {
    try {
      final json = await _store.readMap();
      if (json == null) return PaperChannelPreferences();
      return PaperChannelPreferenceJsonMapper.fromJson(json);
    } catch (error) {
      throw PaperChannelPreferencePersistenceException(
        '无法读取频道偏好。',
        error,
      );
    }
  }

  @override
  Future<void> save(PaperChannelPreferences preferences) async {
    try {
      await _store.writeMap(
        PaperChannelPreferenceJsonMapper.toJson(preferences),
      );
    } catch (error) {
      throw PaperChannelPreferencePersistenceException(
        '无法保存频道偏好。',
        error,
      );
    }
  }
}
