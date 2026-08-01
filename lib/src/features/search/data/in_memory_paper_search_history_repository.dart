import '../domain/paper_search_history_repository.dart';

class InMemoryPaperSearchHistoryRepository
    implements PaperSearchHistoryRepository {
  InMemoryPaperSearchHistoryRepository(
      [Iterable<String> initialHistory = const []])
      : _history = List.of(initialHistory);

  List<String> _history;

  @override
  Future<List<String>> load() async => List.unmodifiable(_history);

  @override
  Future<void> save(List<String> history) async {
    _history = List.of(history);
  }
}
