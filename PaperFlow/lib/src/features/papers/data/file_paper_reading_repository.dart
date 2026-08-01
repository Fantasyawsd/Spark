import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_reading_repository.dart';
import 'paper_reading_json_mapper.dart';

class FilePaperReadingRepository implements PaperReadingRepository {
  FilePaperReadingRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_reading.json'),
          schemaId: 'papers.reading',
          validatePayload: PaperReadingJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<PaperReadingSnapshot> load() async {
    try {
      final json = await _store.readMap();
      if (json == null) return PaperReadingSnapshot();
      return PaperReadingJsonMapper.fromJson(json);
    } catch (error) {
      throw PaperReadingPersistenceException('无法读取论文阅读状态。', error);
    }
  }

  @override
  Future<void> save(PaperReadingSnapshot snapshot) async {
    try {
      await _store.writeMap(PaperReadingJsonMapper.toJson(snapshot));
    } catch (error) {
      throw PaperReadingPersistenceException('无法保存论文阅读状态。', error);
    }
  }
}
