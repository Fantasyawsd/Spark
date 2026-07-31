class ArxivMetadata {
  const ArxivMetadata({
    required this.id,
    required this.title,
    required this.authors,
    required this.abstractText,
    required this.categories,
    required this.publishedAt,
    required this.updatedAt,
    this.primaryCategory,
    this.doi,
    this.journalReference,
    this.comment,
    this.license,
    this.version = 1,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String abstractText;
  final List<String> categories;
  final DateTime publishedAt;
  final DateTime updatedAt;
  final String? primaryCategory;
  final String? doi;
  final String? journalReference;
  final String? comment;
  final String? license;
  final int version;

  String get normalizedId {
    final value = id.trim();
    return value.startsWith('arXiv:') ? value.substring(6) : value;
  }

  String get absUrl => 'https://arxiv.org/abs/$normalizedId';
  String get pdfUrl => 'https://arxiv.org/pdf/$normalizedId';
}

class ArxivMetadataPage {
  const ArxivMetadataPage({
    required this.records,
    this.resumptionToken,
  });

  final List<ArxivMetadata> records;
  final String? resumptionToken;
}

class PaperEnhancement {
  const PaperEnhancement({
    this.citationCount,
    this.institutions = const [],
    this.concepts = const [],
    this.relatedWorkIds = const [],
  });

  final int? citationCount;
  final List<String> institutions;
  final List<String> concepts;
  final List<String> relatedWorkIds;
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
