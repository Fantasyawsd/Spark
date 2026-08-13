import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/features/papers/data/file_paper_keyword_repository.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_record.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_repository.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spark-keywords-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('roundtrips freshness metadata in its versioned envelope', () async {
    final file = _file(directory, 'keywords.json');
    final repository = _repository(file);
    final record = _record(
      'paper-1',
      generatedAt: DateTime.utc(2026, 8, 13, 12, 30),
    );

    await repository.save(record);
    final restored = await repository.load(record.paperId);

    expect(restored?.keywords, record.keywords);
    expect(restored?.inputFingerprint, record.inputFingerprint);
    expect(restored?.promptVersion, record.promptVersion);
    expect(restored?.generatedAt, record.generatedAt);
    final envelope = jsonDecode(await file.readAsString()) as Map;
    expect(envelope['schema'], 'papers.keywords');
    expect(envelope['schemaVersion'], 1);
  });

  test('clear removes only the requested paper', () async {
    final file = _file(directory, 'clear.json');
    final repository = _repository(file);
    await repository.save(_record('paper-1'));
    await repository.save(_record('paper-2'));

    await repository.clear('paper-1');

    expect(await repository.load('paper-1'), isNull);
    expect(await repository.load('paper-2'), isNotNull);
  });

  test(
    'malformed records are quarantined behind the repository exception',
    () async {
      final file = _file(directory, 'malformed.json');
      await file.writeAsString(jsonEncode({'paper-1': 42}));
      final repository = _repository(file);

      await expectLater(
        repository.load('paper-1'),
        throwsA(isA<PaperKeywordPersistenceException>()),
      );

      expect(await file.exists(), isFalse);
      final quarantined = directory.listSync().whereType<File>().where(
            (candidate) => candidate.path.contains('.corrupt.'),
          );
      expect(quarantined, hasLength(1));
    },
  );

  test('concurrent repository instances preserve both records', () async {
    final file = _file(directory, 'concurrent.json');
    final first = _repository(file);
    final second = _repository(file);

    await Future.wait([
      first.save(_record('paper-1')),
      second.save(_record('paper-2')),
    ]);

    expect(await first.load('paper-1'), isNotNull);
    expect(await first.load('paper-2'), isNotNull);
  });
}

FilePaperKeywordRepository _repository(File file) {
  return FilePaperKeywordRepository(
    store: LocalJsonStore(fileName: 'unused.json', file: file),
  );
}

PaperKeywordRecord _record(String paperId, {DateTime? generatedAt}) {
  return PaperKeywordRecord(
    paperId: paperId,
    keywords: const ['A', 'B', 'C', 'D', 'E'],
    inputFingerprint: 'fingerprint-$paperId',
    promptVersion: 1,
    generatedAt: generatedAt ?? DateTime.utc(2026, 8, 13),
  );
}

File _file(Directory directory, String name) {
  return File('${directory.path}${Platform.pathSeparator}$name');
}
