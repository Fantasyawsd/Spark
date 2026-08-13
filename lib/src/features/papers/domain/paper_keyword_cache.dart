class PaperKeywordCache {
  const PaperKeywordCache({
    required this.paperId,
    required this.keywords,
    required this.inputFingerprint,
    required this.promptVersion,
    required this.generatedAt,
  });

  final String paperId;
  final List<String> keywords;
  final String inputFingerprint;
  final int promptVersion;
  final DateTime generatedAt;
}
