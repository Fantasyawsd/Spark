class PaperInteractionSnapshot {
  PaperInteractionSnapshot({
    Iterable<String> likedPaperIds = const [],
    Iterable<String> savedPaperIds = const [],
    Iterable<String> followedPaperIds = const [],
    Map<String, int> shareCountDeltas = const {},
  })  : likedPaperIds = Set.unmodifiable(likedPaperIds),
        savedPaperIds = Set.unmodifiable(savedPaperIds),
        followedPaperIds = Set.unmodifiable(followedPaperIds),
        shareCountDeltas = Map.unmodifiable(shareCountDeltas);

  final Set<String> likedPaperIds;
  final Set<String> savedPaperIds;
  final Set<String> followedPaperIds;
  final Map<String, int> shareCountDeltas;
}

abstract interface class PaperInteractionRepository {
  Future<PaperInteractionSnapshot> load();

  Future<void> save(PaperInteractionSnapshot snapshot);
}

class PaperInteractionPersistenceException implements Exception {
  const PaperInteractionPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
