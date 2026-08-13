import '../domain/paper_keyword_cache.dart';
import '../domain/paper_keyword_repository.dart';

class InMemoryPaperKeywordRepository implements PaperKeywordRepository {
  final Map<String, PaperKeywordCache> _records = {};

  @override
  Future<PaperKeywordCache?> load(String paperId) async => _records[paperId];

  @override
  Future<void> save(PaperKeywordCache cache) async {
    _records[cache.paperId] = cache;
  }

  @override
  Future<void> clear(String paperId) async {
    _records.remove(paperId);
  }
}
