import '../domain/paper_translation.dart';

class PaperTranslationCacheRecord {
  const PaperTranslationCacheRecord({
    required this.paperId,
    required this.markdown,
    required this.inputFingerprint,
    required this.promptVersion,
    required this.generatedAt,
  });

  factory PaperTranslationCacheRecord.fromDomain(
    PaperTranslationRecord translation,
  ) {
    return PaperTranslationCacheRecord(
      paperId: translation.paperId,
      markdown: translation.markdown,
      inputFingerprint: translation.inputFingerprint,
      promptVersion: translation.promptVersion,
      generatedAt: translation.generatedAt,
    );
  }

  final String paperId;
  final String markdown;
  final String inputFingerprint;
  final int promptVersion;
  final DateTime generatedAt;

  PaperTranslationRecord toDomain() {
    return PaperTranslationRecord(
      paperId: paperId,
      markdown: markdown,
      inputFingerprint: inputFingerprint,
      promptVersion: promptVersion,
      generatedAt: generatedAt,
    );
  }
}
