class PaperReadingSnapshot {
  PaperReadingSnapshot({
    Iterable<String> readPaperIds = const [],
    Iterable<String> readLaterPaperIds = const [],
    Iterable<String> historyPaperIds = const [],
    Map<String, int> tabIndices = const {},
    Map<String, double> abstractScrollOffsets = const {},
    Map<String, int> dwellMilliseconds = const {},
  })  : readPaperIds = Set.unmodifiable(readPaperIds),
        readLaterPaperIds = Set.unmodifiable(readLaterPaperIds),
        historyPaperIds = List.unmodifiable(historyPaperIds),
        tabIndices = Map.unmodifiable(tabIndices),
        abstractScrollOffsets = Map.unmodifiable(abstractScrollOffsets),
        dwellMilliseconds = Map.unmodifiable(dwellMilliseconds);

  final Set<String> readPaperIds;
  final Set<String> readLaterPaperIds;
  final List<String> historyPaperIds;
  final Map<String, int> tabIndices;
  final Map<String, double> abstractScrollOffsets;
  final Map<String, int> dwellMilliseconds;
}

abstract interface class PaperReadingRepository {
  Future<PaperReadingSnapshot> load();

  Future<void> save(PaperReadingSnapshot snapshot);
}

class PaperReadingPersistenceException implements Exception {
  const PaperReadingPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
