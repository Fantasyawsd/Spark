class PaperPreferences {
  PaperPreferences({Iterable<String> extraTopics = const []})
      : extraTopics = List.unmodifiable(extraTopics);

  final List<String> extraTopics;
}

abstract interface class PaperPreferenceRepository {
  Future<PaperPreferences> load();

  Future<void> save(PaperPreferences preferences);
}

class PaperPreferencePersistenceException implements Exception {
  const PaperPreferencePersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
