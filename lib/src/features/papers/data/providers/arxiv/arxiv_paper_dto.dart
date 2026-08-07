class ArxivPaperDto {
  const ArxivPaperDto({
    required this.id,
    required this.title,
    required this.summary,
    required this.authors,
    this.affiliations = const [],
    required this.categories,
    required this.publishedAt,
    required this.updatedAt,
    this.paperUrl,
    this.pdfUrl,
    this.primaryCategory,
    this.doi,
    this.journalReference,
    this.comment,
    this.license,
    this.version = 1,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> authors;
  final List<String> affiliations;
  final List<String> categories;
  final DateTime publishedAt;
  final DateTime updatedAt;
  final String? paperUrl;
  final String? pdfUrl;
  final String? primaryCategory;
  final String? doi;
  final String? journalReference;
  final String? comment;
  final String? license;
  final int version;
}

class ArxivPaperPageDto {
  const ArxivPaperPageDto({
    required this.entries,
    required this.startIndex,
    required this.itemsPerPage,
    required this.totalResults,
    required this.nextOffset,
  });

  final List<ArxivPaperDto> entries;
  final int startIndex;
  final int itemsPerPage;
  final int totalResults;
  final int? nextOffset;
}
