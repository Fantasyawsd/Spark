import 'paper_translation_cache_record.dart';

class PaperTranslationJsonMapper {
  const PaperTranslationJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException(
        'Paper translation payload must be an object.',
      );
    }
    for (final entry in payload.entries) {
      if (entry.value is! Map<String, dynamic>) {
        throw const FormatException(
          'Paper translation records must be objects.',
        );
      }
      fromJson(entry.key, entry.value as Map<String, dynamic>);
    }
  }

  static PaperTranslationCacheRecord fromJson(
    String paperId,
    Map<String, dynamic> json,
  ) {
    final markdown = json['markdown'];
    final inputFingerprint = json['inputFingerprint'];
    final promptVersion = json['promptVersion'];
    final generatedAt = json['generatedAt'];
    if (paperId.trim().isEmpty ||
        markdown is! String ||
        markdown.trim().isEmpty ||
        inputFingerprint is! String ||
        inputFingerprint.trim().isEmpty ||
        promptVersion is! int ||
        promptVersion <= 0 ||
        generatedAt is! String) {
      throw const FormatException('Paper translation record is invalid.');
    }
    final parsedGeneratedAt = DateTime.tryParse(generatedAt);
    if (parsedGeneratedAt == null) {
      throw const FormatException('Paper translation generatedAt is invalid.');
    }
    return PaperTranslationCacheRecord(
      paperId: paperId,
      markdown: markdown,
      inputFingerprint: inputFingerprint,
      promptVersion: promptVersion,
      generatedAt: parsedGeneratedAt.toUtc(),
    );
  }

  static Map<String, dynamic> toJson(PaperTranslationCacheRecord record) => {
        'markdown': record.markdown,
        'inputFingerprint': record.inputFingerprint,
        'promptVersion': record.promptVersion,
        'generatedAt': record.generatedAt.toUtc().toIso8601String(),
      };
}
