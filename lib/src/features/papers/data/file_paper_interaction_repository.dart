import '../../../core/storage/local_json_store.dart';
import '../domain/paper_interaction_repository.dart';
import 'paper_file_persistence.dart';
import 'paper_interaction_record.dart';
import 'paper_interaction_json_mapper.dart';

class FilePaperInteractionRepository implements PaperInteractionRepository {
  FilePaperInteractionRepository({LocalJsonStore? store})
      : _persistence = PaperFilePersistence(
          fileName: 'paper_interactions.json',
          schemaId: 'papers.interactions',
          schemaVersion: 2,
          migrations: const {1: PaperInteractionJsonMapper.migrateV1ToV2},
          validatePayload: PaperInteractionJsonMapper.validatePayload,
          store: store,
        );

  final PaperFilePersistence _persistence;

  @override
  Future<PaperInteractionSnapshot> load() {
    return _persistence.guard(() async {
      final json = await _persistence.store.readMap();
      if (json == null) return PaperInteractionSnapshot();
      return PaperInteractionJsonMapper.fromJson(json).toDomain();
    }, (error) => PaperInteractionPersistenceException('无法读取论文互动状态。', error));
  }

  @override
  Future<void> save(PaperInteractionSnapshot snapshot) {
    return _persistence.guard(
      () => _persistence.store.writeMap(
        PaperInteractionJsonMapper.toJson(
          PaperInteractionRecord.fromDomain(snapshot),
        ),
      ),
      (error) => PaperInteractionPersistenceException('无法保存论文互动状态。', error),
    );
  }
}
