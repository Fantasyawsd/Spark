import '../domain/paper_interaction_repository.dart';

class InMemoryPaperInteractionRepository implements PaperInteractionRepository {
  InMemoryPaperInteractionRepository([PaperInteractionSnapshot? initial])
      : _snapshot = initial ?? PaperInteractionSnapshot();

  PaperInteractionSnapshot _snapshot;

  @override
  Future<PaperInteractionSnapshot> load() async => _snapshot;

  @override
  Future<void> save(PaperInteractionSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}
