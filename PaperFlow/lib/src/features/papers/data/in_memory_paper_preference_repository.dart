import '../domain/paper_preference_repository.dart';

class InMemoryPaperPreferenceRepository implements PaperPreferenceRepository {
  InMemoryPaperPreferenceRepository([PaperPreferences? initial])
      : _preferences = initial ?? PaperPreferences();

  PaperPreferences _preferences;

  @override
  Future<PaperPreferences> load() async => _preferences;

  @override
  Future<void> save(PaperPreferences preferences) async {
    _preferences = preferences;
  }
}
