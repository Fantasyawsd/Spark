import 'paper_cache_record.dart';
import 'paper_cache_store.dart';

class InMemoryPaperCacheStore implements PaperCacheStore {
  final Map<String, PaperCacheRecord> _papers = {};
  final Map<String, PaperPageCacheRecord> _pages = {};

  @override
  Future<CachedPaperPageRecord?> readPage(String queryKey) async {
    final page = _pages[queryKey];
    if (page == null) return null;
    return CachedPaperPageRecord(
      page: page,
      papers: page.paperIds
          .map((paperId) => _papers[paperId])
          .whereType<PaperCacheRecord>()
          .toList(growable: false),
    );
  }

  @override
  Future<PaperCacheRecord?> readPaper(String paperId) async => _papers[paperId];

  @override
  Future<void> writePage({
    required PaperPageCacheRecord page,
    required Iterable<PaperCacheRecord> papers,
  }) async {
    for (final paper in papers) {
      _papers[paper.id] = paper;
    }
    _pages[page.queryKey] = page;
  }

  @override
  Future<void> writePaper(PaperCacheRecord paper) async {
    _papers[paper.id] = paper;
  }
}
