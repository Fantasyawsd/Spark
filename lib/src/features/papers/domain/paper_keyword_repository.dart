import 'paper_keyword_record.dart';

abstract interface class PaperKeywordRepository {
  Future<PaperKeywordRecord?> load(String paperId);

  Future<void> save(PaperKeywordRecord record);

  Future<void> clear(String paperId);
}

class PaperKeywordPersistenceException implements Exception {
  const PaperKeywordPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
