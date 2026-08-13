import '../domain/paper_keyword_cache.dart';

class PaperKeywordCacheRecord {
  const PaperKeywordCacheRecord({
    required this.paperId,
    required this.keywords,
    required this.inputFingerprint,
    required this.promptVersion,
    required this.generatedAt,
  });

  factory PaperKeywordCacheRecord.fromDomain(PaperKeywordCache cache) {
    return PaperKeywordCacheRecord(
      paperId: cache.paperId,
      keywords: cache.keywords,
      inputFingerprint: cache.inputFingerprint,
      promptVersion: cache.promptVersion,
      generatedAt: cache.generatedAt,
    );
  }

  final String paperId;
  final List<String> keywords;
  final String inputFingerprint;
  final int promptVersion;
  final DateTime generatedAt;

  PaperKeywordCache toDomain() {
    return PaperKeywordCache(
      paperId: paperId,
      keywords: List<String>.unmodifiable(keywords),
      inputFingerprint: inputFingerprint,
      promptVersion: promptVersion,
      generatedAt: generatedAt,
    );
  }
}
