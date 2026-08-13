import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/data/paper_reading_json_mapper.dart';
import 'package:spark/src/features/papers/data/paper_reading_record.dart';
import 'package:spark/src/features/papers/domain/paper_reading_repository.dart';

void main() {
  test('reading record maps between JSON and the domain snapshot', () {
    final snapshot = PaperReadingSnapshot(
      readPaperIds: const ['paper-1'],
      readLaterPaperIds: const ['paper-2'],
      historyPaperIds: const ['paper-2', 'paper-1'],
      tabIndices: const {'paper-1': 2},
      abstractScrollOffsets: const {'paper-1': 31.5},
      dwellMilliseconds: const {'paper-1': 800},
    );

    final record = PaperReadingRecord.fromDomain(snapshot);
    final json = PaperReadingJsonMapper.toJson(record);
    final restoredRecord = PaperReadingJsonMapper.fromJson(json);
    final restored = restoredRecord.toDomain();

    expect(restoredRecord, isA<PaperReadingRecord>());
    expect(restored.readPaperIds, snapshot.readPaperIds);
    expect(restored.readLaterPaperIds, snapshot.readLaterPaperIds);
    expect(restored.historyPaperIds, snapshot.historyPaperIds);
    expect(restored.tabIndices, snapshot.tabIndices);
    expect(restored.abstractScrollOffsets, snapshot.abstractScrollOffsets);
    expect(restored.dwellMilliseconds, snapshot.dwellMilliseconds);
    expect(json, {
      'readPaperIds': ['paper-1'],
      'readLaterPaperIds': ['paper-2'],
      'historyPaperIds': ['paper-2', 'paper-1'],
      'tabIndices': {'paper-1': 2},
      'abstractScrollOffsets': {'paper-1': 31.5},
      'dwellMilliseconds': {'paper-1': 800},
    });
  });
}
