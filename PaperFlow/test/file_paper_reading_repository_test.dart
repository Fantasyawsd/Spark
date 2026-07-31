import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/core/storage/local_json_store.dart';

void main() {
  test('restores reading state after repository recreation', () async {
    final directory = await Directory.systemTemp.createTemp('paper-reading-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}reading.json');
    final first = FilePaperReadingRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    await first.save(
      PaperReadingSnapshot(
        readPaperIds: const ['paper-1'],
        readLaterPaperIds: const ['paper-2'],
        historyPaperIds: const ['paper-2', 'paper-1'],
        tabIndices: const {'paper-1': 2},
        abstractScrollOffsets: const {'paper-1': 31.5},
        dwellMilliseconds: const {'paper-1': 800},
      ),
    );

    final restored = await FilePaperReadingRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    ).load();

    expect(restored.readPaperIds, {'paper-1'});
    expect(restored.readLaterPaperIds, {'paper-2'});
    expect(restored.historyPaperIds, ['paper-2', 'paper-1']);
    expect(restored.tabIndices, {'paper-1': 2});
    expect(restored.abstractScrollOffsets, {'paper-1': 31.5});
    expect(restored.dwellMilliseconds, {'paper-1': 800});
  });

  test('reports malformed reading data as a persistence error', () async {
    final directory =
        await Directory.systemTemp.createTemp('paper-reading-bad-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}reading.json');
    await file.writeAsString('[]');
    final repository = FilePaperReadingRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    expect(
      repository.load,
      throwsA(isA<PaperReadingPersistenceException>()),
    );
  });
}
