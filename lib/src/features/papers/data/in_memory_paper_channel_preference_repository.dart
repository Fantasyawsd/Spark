import '../domain/paper_channel_preference_repository.dart';

class InMemoryPaperChannelPreferenceRepository
    implements PaperChannelPreferenceRepository {
  InMemoryPaperChannelPreferenceRepository([PaperChannelPreferences? initial])
      : _preferences = initial ?? PaperChannelPreferences();

  PaperChannelPreferences _preferences;

  @override
  Future<PaperChannelPreferences> load() async => _preferences;

  @override
  Future<void> save(PaperChannelPreferences preferences) async {
    _preferences = preferences;
  }
}
