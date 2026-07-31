class PaperRecord {
  const PaperRecord({
    required this.id,
    required this.venue,
    required this.title,
    required this.authors,
    required this.firstAffiliation,
    required this.topics,
    required this.abstractText,
    required this.chineseAbstractMarkdown,
    required this.relatedPapersMarkdown,
    required this.readMinutes,
    required this.citations,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    this.arxivId,
    this.doi,
    this.paperUrl,
    this.pdfUrl,
    this.publishedAt,
    this.updatedAt,
    this.license,
    this.source = 'demo',
  });

  final String id;
  final String venue;
  final String title;
  final String authors;
  final String firstAffiliation;
  final List<String> topics;
  final String abstractText;
  final String chineseAbstractMarkdown;
  final String relatedPapersMarkdown;
  final int readMinutes;
  final String citations;
  final String likes;
  final String comments;
  final String saves;
  final String shares;
  final String? arxivId;
  final String? doi;
  final String? paperUrl;
  final String? pdfUrl;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final String? license;
  final String source;
}

extension PaperAuthorIdentity on PaperRecord {
  String get authorKey {
    final firstAuthor = authors
        .split(',')
        .map((name) => name.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => id);
    return 'author:${firstAuthor.toLowerCase()}';
  }
}
