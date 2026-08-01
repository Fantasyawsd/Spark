class Paper {
  Paper({
    required this.id,
    required this.venue,
    required this.title,
    required List<String> authors,
    required this.firstAffiliation,
    required List<String> topics,
    required String abstractText,
    required String chineseAbstractMarkdown,
    List<RelatedPaper> relatedPapers = const [],
    required this.readMinutes,
    int citations = 0,
    int likes = 0,
    int comments = 0,
    int saves = 0,
    int shares = 0,
    this.arxivId,
    this.doi,
    this.paperUrl,
    this.pdfUrl,
    this.publishedAt,
    this.updatedAt,
    this.license,
    this.source = 'demo',
  })  : authors = List.unmodifiable(authors),
        topics = List.unmodifiable(topics),
        relatedPapers = List.unmodifiable(relatedPapers),
        content = PaperContent(
          originalAbstractMarkdown: abstractText,
          chineseAbstractMarkdown: chineseAbstractMarkdown,
        ),
        metrics = PaperMetrics(
          citations: citations,
          likes: likes,
          comments: comments,
          saves: saves,
          shares: shares,
        );

  final String id;
  final String venue;
  final String title;
  final List<String> authors;
  final String firstAffiliation;
  final List<String> topics;
  final PaperContent content;
  final List<RelatedPaper> relatedPapers;
  final int readMinutes;
  final PaperMetrics metrics;
  final String? arxivId;
  final String? doi;
  final String? paperUrl;
  final String? pdfUrl;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final String? license;
  final String source;

  String get firstAuthor => authors.firstWhere(
        (author) => author.trim().isNotEmpty,
        orElse: () => id,
      );
}

class PaperContent {
  const PaperContent({
    required this.originalAbstractMarkdown,
    required this.chineseAbstractMarkdown,
  });

  final String originalAbstractMarkdown;
  final String chineseAbstractMarkdown;
}

class PaperMetrics {
  const PaperMetrics({
    this.citations = 0,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
  });

  final int citations;
  final int likes;
  final int comments;
  final int saves;
  final int shares;

  PaperMetrics copyWith({
    int? citations,
    int? likes,
    int? comments,
    int? saves,
    int? shares,
  }) {
    return PaperMetrics(
      citations: citations ?? this.citations,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      saves: saves ?? this.saves,
      shares: shares ?? this.shares,
    );
  }
}

class RelatedPaper {
  const RelatedPaper({
    required this.id,
    required this.title,
    required this.venue,
    required this.relation,
  });

  final String id;
  final String title;
  final String venue;
  final String relation;
}

extension PaperAuthorIdentity on Paper {
  String get authorKey => 'author:${firstAuthor.trim().toLowerCase()}';
}
