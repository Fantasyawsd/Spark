abstract interface class PaperSearchHistoryRepository {
  Future<List<String>> load();

  Future<void> save(List<String> history);
}

class PaperSearchHistoryException implements Exception {
  const PaperSearchHistoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
