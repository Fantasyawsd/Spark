import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/core/storage/local_json_store.dart';
import 'package:paperflow/src/core/storage/versioned_local_json_store.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('paperflow-records-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('interaction repository rejects invalid record fields', () async {
    final file = _file(directory, 'interactions.json');
    await file.writeAsString(jsonEncode({
      'likedPaperIds': ['paper-1', 2],
      'savedPaperIds': [],
      'followedPaperIds': [],
      'shareCountDeltas': {},
    }));
    final repository = FilePaperInteractionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    await expectLater(
      repository.load(),
      throwsA(isA<PaperInteractionPersistenceException>()),
    );
    expect(await file.exists(), isFalse);
  });

  test('preference repository persists its independent schema identifier',
      () async {
    final file = _file(directory, 'preferences.json');
    final repository = FilePaperPreferenceRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    await repository.save(PaperPreferences(extraTopics: const ['Agent']));

    final envelope = jsonDecode(await file.readAsString()) as Map;
    expect(envelope['schema'], 'papers.preferences');
    expect(envelope['schemaVersion'], 1);
  });

  test('translation repository rejects non-string cached translations',
      () async {
    final file = _file(directory, 'translations.json');
    await file.writeAsString(jsonEncode({'paper-1': 42}));
    final repository = FilePaperTranslationRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    await expectLater(
      repository.load('paper-1'),
      throwsA(isA<PaperTranslationPersistenceException>()),
    );
    expect(await file.exists(), isFalse);
  });

  test('interaction save cannot overwrite a future schema', () async {
    final file = _file(directory, 'future.json');
    final original = jsonEncode({
      '_format': VersionedLocalJsonStore.format,
      'formatVersion': 1,
      'schema': 'papers.interactions',
      'schemaVersion': 99,
      'payload': <String, dynamic>{},
    });
    await file.writeAsString(original);
    final repository = FilePaperInteractionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    await expectLater(
      repository.save(PaperInteractionSnapshot(likedPaperIds: const ['p1'])),
      throwsA(isA<PaperInteractionPersistenceException>()),
    );
    expect(await file.readAsString(), original);
  });
}

File _file(Directory directory, String name) {
  return File('${directory.path}${Platform.pathSeparator}$name');
}
