class ArxivAtomPaperDto {
  const ArxivAtomPaperDto({
    required this.id,
    required this.title,
    required this.summary,
    required this.authors,
    required this.affiliations,
    required this.categories,
    required this.publishedAt,
    required this.updatedAt,
    required this.paperUrl,
    required this.pdfUrl,
    this.primaryCategory,
    this.doi,
    this.journalReference,
    this.comment,
    this.license,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> authors;
  final List<String> affiliations;
  final List<String> categories;
  final DateTime publishedAt;
  final DateTime updatedAt;
  final String paperUrl;
  final String pdfUrl;
  final String? primaryCategory;
  final String? doi;
  final String? journalReference;
  final String? comment;
  final String? license;
}

class ArxivAtomPageDto {
  const ArxivAtomPageDto({
    required this.entries,
    required this.startIndex,
    required this.itemsPerPage,
    required this.totalResults,
    required this.nextOffset,
  });

  final List<ArxivAtomPaperDto> entries;
  final int startIndex;
  final int itemsPerPage;
  final int totalResults;
  final int? nextOffset;
}
