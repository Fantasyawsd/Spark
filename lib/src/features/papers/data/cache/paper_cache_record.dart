class PaperCacheRecord {
  const PaperCacheRecord({
    required this.id,
    required this.venue,
    required this.title,
    required this.authors,
    required this.firstAffiliation,
    required this.topics,
    required this.abstractMarkdown,
    required this.chineseAbstractMarkdown,
    required this.relatedPapers,
    required this.readMinutes,
    required this.citations,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    required this.source,
    required this.cachedAt,
    this.arxivId,
    this.doi,
    this.paperUrl,
    this.pdfUrl,
    this.publishedAt,
    this.updatedAt,
    this.license,
  });

  final String id;
  final String venue;
  final String title;
  final List<String> authors;
  final String firstAffiliation;
  final List<String> topics;
  final String abstractMarkdown;
  final String chineseAbstractMarkdown;
  final List<RelatedPaperCacheRecord> relatedPapers;
  final int readMinutes;
  final int citations;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
  final String? arxivId;
  final String? doi;
  final String? paperUrl;
  final String? pdfUrl;
  final String? publishedAt;
  final String? updatedAt;
  final String? license;
  final String source;
  final String cachedAt;
}

class RelatedPaperCacheRecord {
  const RelatedPaperCacheRecord({
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

class PaperPageCacheRecord {
  const PaperPageCacheRecord({
    required this.queryKey,
    required this.paperIds,
    required this.fetchedAt,
    required this.nextOffset,
  });

  final String queryKey;
  final List<String> paperIds;
  final String fetchedAt;
  final int? nextOffset;
}

class PaperCacheSnapshotRecord {
  const PaperCacheSnapshotRecord({
    required this.papers,
    required this.pages,
  });

  const PaperCacheSnapshotRecord.empty()
      : papers = const {},
        pages = const {};

  final Map<String, PaperCacheRecord> papers;
  final Map<String, PaperPageCacheRecord> pages;
}
