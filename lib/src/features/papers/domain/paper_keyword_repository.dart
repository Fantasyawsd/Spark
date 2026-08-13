import 'paper_keyword_cache.dart';

abstract interface class PaperKeywordRepository {
  Future<PaperKeywordCache?> load(String paperId);

  Future<void> save(PaperKeywordCache cache);

  Future<void> clear(String paperId);
}

class PaperKeywordPersistenceException implements Exception {
  const PaperKeywordPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
