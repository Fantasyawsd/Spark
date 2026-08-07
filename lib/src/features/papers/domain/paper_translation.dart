import 'paper.dart';

abstract interface class PaperTranslationService {
  Stream<String> translateAbstract(Paper paper);

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
  Future<PaperTranslationRecord?> load(String paperId);

  Future<void> save(PaperTranslationRecord record);

  Future<void> clear(String paperId);
}

class PaperTranslationPersistenceException implements Exception {
  const PaperTranslationPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class PaperTranslationRecord {
  const PaperTranslationRecord({
    required this.paperId,
    required this.markdown,
    required this.inputFingerprint,
    required this.promptVersion,
    required this.generatedAt,
  });

  final String paperId;
  final String markdown;
  final String inputFingerprint;
  final int promptVersion;
  final DateTime generatedAt;
}
