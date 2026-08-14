class Paper {
  Paper({
    required this.id,
    required this.title,
    required List<String> authors,
    List<String> affiliations = const [],
    List<String> contentKeywords = const [],
    List<String> subjects = const [],
    this.primarySubject,
    this.venue,
    this.journalReference,
    this.comment,
    required String abstractText,
    required String chineseAbstractMarkdown,
    List<RelatedPaper> relatedPapers = const [],
    required this.readMinutes,
    int? citations,
    int likes = 0,
    int comments = 0,
    int saves = 0,
    int shares = 0,
    this.arxivId,
    this.doi,
    this.paperUrl,
    this.webTrendReason,
    List<String> webTrendTopics = const [],
    this.pdfUrl,
    this.publishedAt,
    this.updatedAt,
    this.license,
    this.source = 'demo',
    this.personalizationScore,
    this.recommendationPool,
  })  : authors = List.unmodifiable(authors),
        affiliations = List.unmodifiable(affiliations),
        contentKeywords = List.unmodifiable(contentKeywords),
        subjects = List.unmodifiable(subjects),
        relatedPapers = List.unmodifiable(relatedPapers),
        webTrendTopics = List.unmodifiable(webTrendTopics),
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
  final String title;
  final List<String> authors;
  final List<String> affiliations;
  final List<String> contentKeywords;
  final List<String> subjects;
  final String? primarySubject;
  final String? venue;
  final String? journalReference;
  final String? comment;
  final PaperContent content;
  final List<RelatedPaper> relatedPapers;
  final int readMinutes;
  final PaperMetrics metrics;
  final String? arxivId;
  final String? doi;
  final String? paperUrl;
  final String? webTrendReason;
  final List<String> webTrendTopics;
  final String? pdfUrl;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final String? license;
  final String source;

  /// 个性化推荐分数；null 表示未参与个性化排序。
  final double? personalizationScore;

  /// 服务端推荐池标记（high_impact / trending / personalized）；
  /// production arXiv 直连时无此字段。
  final String? recommendationPool;

  String get firstAuthor => authors.firstWhere(
        (author) => author.trim().isNotEmpty,
        orElse: () => id,
      );

  String? get firstAffiliation {
    for (final affiliation in affiliations) {
      if (affiliation.trim().isNotEmpty) return affiliation;
    }
    return null;
  }

  Paper copyWith({
    String? id,
    String? title,
    List<String>? authors,
    List<String>? affiliations,
    List<String>? contentKeywords,
    List<String>? subjects,
    String? primarySubject,
    bool clearPrimarySubject = false,
    String? venue,
    bool clearVenue = false,
    String? journalReference,
    bool clearJournalReference = false,
    String? comment,
    bool clearComment = false,
    String? abstractText,
    String? chineseAbstractMarkdown,
    List<RelatedPaper>? relatedPapers,
    int? readMinutes,
    int? citations,
    bool clearCitations = false,
    int? likes,
    int? comments,
    int? saves,
    int? shares,
    String? arxivId,
    bool clearArxivId = false,
    String? doi,
    bool clearDoi = false,
    String? paperUrl,
    bool clearPaperUrl = false,
    String? webTrendReason,
    bool clearWebTrendReason = false,
    List<String>? webTrendTopics,
    String? pdfUrl,
    bool clearPdfUrl = false,
    DateTime? publishedAt,
    bool clearPublishedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    String? license,
    bool clearLicense = false,
    String? source,
    double? personalizationScore,
    bool clearPersonalizationScore = false,
    String? recommendationPool,
  }) {
    return Paper(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      affiliations: affiliations ?? this.affiliations,
      contentKeywords: contentKeywords ?? this.contentKeywords,
      subjects: subjects ?? this.subjects,
      primarySubject:
          clearPrimarySubject ? null : primarySubject ?? this.primarySubject,
      venue: clearVenue ? null : venue ?? this.venue,
      journalReference: clearJournalReference
          ? null
          : journalReference ?? this.journalReference,
      comment: clearComment ? null : comment ?? this.comment,
      abstractText: abstractText ?? content.originalAbstractMarkdown,
      chineseAbstractMarkdown:
          chineseAbstractMarkdown ?? content.chineseAbstractMarkdown,
      relatedPapers: relatedPapers ?? this.relatedPapers,
      readMinutes: readMinutes ?? this.readMinutes,
      citations: clearCitations ? null : citations ?? metrics.citations,
      likes: likes ?? metrics.likes,
      comments: comments ?? metrics.comments,
      saves: saves ?? metrics.saves,
      shares: shares ?? metrics.shares,
      arxivId: clearArxivId ? null : arxivId ?? this.arxivId,
      doi: clearDoi ? null : doi ?? this.doi,
      paperUrl: clearPaperUrl ? null : paperUrl ?? this.paperUrl,
      webTrendReason:
          clearWebTrendReason ? null : webTrendReason ?? this.webTrendReason,
      webTrendTopics: webTrendTopics ?? this.webTrendTopics,
      pdfUrl: clearPdfUrl ? null : pdfUrl ?? this.pdfUrl,
      publishedAt: clearPublishedAt ? null : publishedAt ?? this.publishedAt,
      updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
      license: clearLicense ? null : license ?? this.license,
      source: source ?? this.source,
      personalizationScore: clearPersonalizationScore
          ? null
          : personalizationScore ?? this.personalizationScore,
      recommendationPool: recommendationPool ?? this.recommendationPool,
    );
  }
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
    this.citations,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
  });

  /// 引用数；`null` 表示未知，不使用 0 冒充真实数据。
  final int? citations;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
}

class RelatedPaper {
  const RelatedPaper({
    required this.id,
    required this.title,
    this.venue,
    required this.relation,
  });

  final String id;
  final String title;
  final String? venue;
  final String relation;
}

extension PaperAuthorIdentity on Paper {
  String get authorKey => 'author:${firstAuthor.trim().toLowerCase()}';
}
