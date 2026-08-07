import '../domain/paper_keyword_record.dart';
import '../domain/paper_keyword_repository.dart';

class InMemoryPaperKeywordRepository implements PaperKeywordRepository {
  final Map<String, PaperKeywordRecord> _records = {};

  @override
  Future<PaperKeywordRecord?> load(String paperId) async => _records[paperId];

  @override
  Future<void> save(PaperKeywordRecord record) async {
    _records[record.paperId] = record;
  }

  @override
  Future<void> clear(String paperId) async {
    _records.remove(paperId);
  }
}
