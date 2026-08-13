import '../../../core/storage/local_json_store.dart';
import '../domain/paper_reading_repository.dart';
import 'paper_file_persistence.dart';
import 'paper_reading_json_mapper.dart';
import 'paper_reading_record.dart';

class FilePaperReadingRepository implements PaperReadingRepository {
  FilePaperReadingRepository({LocalJsonStore? store})
    : _persistence = PaperFilePersistence(
        fileName: 'paper_reading.json',
        schemaId: 'papers.reading',
        validatePayload: PaperReadingJsonMapper.validatePayload,
        store: store,
      );

  final PaperFilePersistence _persistence;

  @override
  Future<PaperReadingSnapshot> load() {
    return _persistence.guard(() async {
      final json = await _persistence.store.readMap();
      if (json == null) return PaperReadingSnapshot();
      return PaperReadingJsonMapper.fromJson(json).toDomain();
    }, (error) => PaperReadingPersistenceException('无法读取论文阅读状态。', error));
  }

  @override
  Future<void> save(PaperReadingSnapshot snapshot) {
    final record = PaperReadingRecord.fromDomain(snapshot);
    return _persistence.guard(
      () => _persistence.store.writeMap(PaperReadingJsonMapper.toJson(record)),
      (error) => PaperReadingPersistenceException('无法保存论文阅读状态。', error),
    );
  }
}
