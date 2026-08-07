import 'paper_cache_record.dart';

class PaperCachePolicy {
  const PaperCachePolicy({
    this.detailTtl = const Duration(days: 7),
    this.retention = const Duration(days: 30),
    this.maxPages = 100,
    this.maxPapers = 1000,
  })  : assert(maxPages > 0),
        assert(maxPapers > 0);

  final Duration detailTtl;
  final Duration retention;
  final int maxPages;
  final int maxPapers;

  bool isDetailFresh(DateTime cachedAt, DateTime now) {
    return now.toUtc().isBefore(cachedAt.toUtc().add(detailTtl));
  }
}

class CachedPaperPageRecord {
  const CachedPaperPageRecord({required this.page, required this.papers});

  final PaperPageCacheRecord page;
  final List<PaperCacheRecord> papers;
}

abstract interface class PaperCacheStore {
  Future<CachedPaperPageRecord?> readPage(String queryKey);

  Future<PaperCacheRecord?> readPaper(String paperId);

  Future<void> writePage({
    required PaperPageCacheRecord page,
    required Iterable<PaperCacheRecord> papers,
  });

  Future<void> writePaper(PaperCacheRecord paper);
}
