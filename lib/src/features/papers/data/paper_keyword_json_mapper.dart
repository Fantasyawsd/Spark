import 'paper_keyword_cache_record.dart';

class PaperKeywordJsonMapper {
  const PaperKeywordJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Paper keyword payload must be an object.');
    }
    for (final entry in payload.entries) {
      if (entry.value is! Map<String, dynamic>) {
        throw const FormatException('Paper keyword records must be objects.');
      }
      fromJson(entry.key, entry.value as Map<String, dynamic>);
    }
  }

  static PaperKeywordCacheRecord fromJson(
    String paperId,
    Map<String, dynamic> json,
  ) {
    final keywords = json['keywords'];
    final inputFingerprint = json['inputFingerprint'];
    final promptVersion = json['promptVersion'];
    final generatedAt = json['generatedAt'];
    if (keywords is! List ||
        keywords.any((value) => value is! String) ||
        inputFingerprint is! String ||
        promptVersion is! int ||
        generatedAt is! String) {
      throw const FormatException('Paper keyword record is invalid.');
    }
    final parsedGeneratedAt = DateTime.tryParse(generatedAt);
    if (parsedGeneratedAt == null) {
      throw const FormatException('Paper keyword generatedAt is invalid.');
    }
    return PaperKeywordCacheRecord(
      paperId: paperId,
      keywords: List<String>.unmodifiable(keywords.cast<String>()),
      inputFingerprint: inputFingerprint,
      promptVersion: promptVersion,
      generatedAt: parsedGeneratedAt,
    );
  }

  static Map<String, dynamic> toJson(PaperKeywordCacheRecord record) => {
        'keywords': record.keywords,
        'inputFingerprint': record.inputFingerprint,
        'promptVersion': record.promptVersion,
        'generatedAt': record.generatedAt.toUtc().toIso8601String(),
      };
}
