import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_interaction_repository.dart';
import 'paper_interaction_json_mapper.dart';

class FilePaperInteractionRepository implements PaperInteractionRepository {
  FilePaperInteractionRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_interactions.json'),
          schemaId: 'papers.interactions',
          schemaVersion: 2,
          migrations: const {1: PaperInteractionJsonMapper.migrateV1ToV2},
          validatePayload: PaperInteractionJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<PaperInteractionSnapshot> load() async {
    try {
      final json = await _store.readMap();
      if (json == null) return PaperInteractionSnapshot();
      return PaperInteractionJsonMapper.fromJson(json);
    } catch (error) {
      throw PaperInteractionPersistenceException('无法读取论文互动状态。', error);
    }
  }

  @override
  Future<void> save(PaperInteractionSnapshot snapshot) async {
    try {
      await _store.writeMap(PaperInteractionJsonMapper.toJson(snapshot));
    } catch (error) {
      throw PaperInteractionPersistenceException('无法保存论文互动状态。', error);
    }
  }
}
