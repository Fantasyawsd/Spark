import 'paper.dart';

enum PaperPageSource { remote, cache, seed }

enum PaperCatalogErrorKind {
  network,
  timeout,
  invalidResponse,
  unavailable,
}

class PaperCatalogError {
  const PaperCatalogError({required this.kind, required this.message});

  final PaperCatalogErrorKind kind;
  final String message;
}

class PaperFeedQuery {
  const PaperFeedQuery({
    this.category,
    this.offset = 0,
    this.limit = 20,
    this.forceRefresh = false,
  })  : assert(offset >= 0),
        assert(limit > 0);

  final String? category;
  final int offset;
  final int limit;
  final bool forceRefresh;

  PaperFeedQuery nextPage(int nextOffset) {
    return PaperFeedQuery(
      category: category,
      offset: nextOffset,
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }
}

class PaperSearchQuery {
  const PaperSearchQuery({
    required this.term,
    this.offset = 0,
    this.limit = 20,
    this.forceRefresh = false,
  })  : assert(offset >= 0),
        assert(limit > 0);

  final String term;
  final int offset;
  final int limit;
  final bool forceRefresh;

  PaperSearchQuery nextPage(int nextOffset) {
    return PaperSearchQuery(
      term: term,
      offset: nextOffset,
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }
}

class PaperPage {
  PaperPage({
    required List<Paper> papers,
    required this.source,
    this.nextOffset,
    this.isStale = false,
    this.isOffline = false,
    this.error,
  }) : papers = List.unmodifiable(papers);

  final List<Paper> papers;
  final PaperPageSource source;
  final int? nextOffset;
  final bool isStale;
  final bool isOffline;
  final PaperCatalogError? error;

  bool get hasMore => nextOffset != null;
}

abstract interface class PaperCatalogRepository {
  Future<PaperPage> loadFeed(PaperFeedQuery query);

  Future<PaperPage> search(PaperSearchQuery query);

  Future<Paper?> findById(String paperId);
}
