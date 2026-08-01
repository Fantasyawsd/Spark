class PaperPreferences {
  PaperPreferences({
    Iterable<String> extraTopics = const [],
    Map<String, int> positions = const {},
    this.primaryCategoryIndex = 0,
    this.topicIndex = 0,
  })  : extraTopics = List.unmodifiable(extraTopics),
        positions = Map.unmodifiable(positions);

  final List<String> extraTopics;
  final Map<String, int> positions;
  final int primaryCategoryIndex;
  final int topicIndex;
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
