import '../domain/paper_reading_repository.dart';

class InMemoryPaperReadingRepository implements PaperReadingRepository {
  InMemoryPaperReadingRepository([PaperReadingSnapshot? initial])
      : _snapshot = initial ?? PaperReadingSnapshot();

  PaperReadingSnapshot _snapshot;

  @override
  Future<PaperReadingSnapshot> load() async => _snapshot;

  @override
  Future<void> save(PaperReadingSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}
