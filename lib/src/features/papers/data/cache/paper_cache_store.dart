import 'paper_cache_record.dart';

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
