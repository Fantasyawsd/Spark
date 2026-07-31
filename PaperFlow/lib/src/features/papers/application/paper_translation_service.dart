import '../domain/paper.dart';

abstract interface class PaperTranslationService {
  Stream<String> translateAbstract(PaperRecord paper);

  void cancelActiveTranslation();
}

abstract interface class PaperTranslationServiceFactory {
  PaperTranslationService create();
}

class PaperTranslationException implements Exception {
  const PaperTranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class PaperTranslationRepository {
  Future<String?> load(String paperId);

  Future<void> save(String paperId, String markdown);

  Future<void> clear(String paperId);
}

class PaperTranslationPersistenceException implements Exception {
  const PaperTranslationPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
