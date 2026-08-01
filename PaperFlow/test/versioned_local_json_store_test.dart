import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/core/storage/local_json_store.dart';
import 'package:paperflow/src/core/storage/versioned_local_json_store.dart';

void main() {
  late Directory directory;
  late File file;
  late VersionedLocalJsonStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('paperflow-schema-');
    file = File('${directory.path}${Platform.pathSeparator}state.json');
    store = VersionedLocalJsonStore(
      LocalJsonStore(fileName: 'unused.json', file: file),
      schemaId: 'test.state',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('migrates a legacy object into the current schema envelope', () async {
    await file.writeAsString('{"likedPaperIds":["paper-1"]}');

    final payload = await store.readMap();

    expect(payload, {
      'likedPaperIds': ['paper-1'],
    });
    final migrated = jsonDecode(await file.readAsString()) as Map;
    expect(migrated['_format'], VersionedLocalJsonStore.format);
    expect(migrated['formatVersion'], 1);
    expect(migrated['schema'], 'test.state');
    expect(migrated['revision'], 1);
    expect(
      migrated['schemaVersion'],
      VersionedLocalJsonStore.currentSchemaVersion,
    );
    expect(migrated['payload'], payload);
  });

  test('legacy business keys do not collide with the storage envelope',
      () async {
    await file.writeAsString(
      '{"schemaVersion":7,"payload":"business value"}',
    );

    expect(await store.readMap(), {
      'schemaVersion': 7,
      'payload': 'business value',
    });
    final migrated = jsonDecode(await file.readAsString()) as Map;
    expect(migrated['_format'], VersionedLocalJsonStore.format);
    expect(migrated['schemaVersion'], 1);
  });

  test('writes and restores a versioned list payload', () async {
    await store.writeList(['LoRA', 'Mamba']);

    expect(await store.readList(), ['LoRA', 'Mamba']);
    final stored = jsonDecode(await file.readAsString()) as Map;
    expect(stored['schemaVersion'], 1);
    expect(stored['payload'], ['LoRA', 'Mamba']);
  });

  test('quarantines malformed JSON and allows a clean subsequent read',
      () async {
    await file.writeAsString('{broken json');

    LocalDataCorruptionException? failure;
    try {
      await store.readMap();
    } on LocalDataCorruptionException catch (error) {
      failure = error;
    }

    expect(failure, isNotNull);
    expect(failure!.backupPath, isNotNull);
    expect(await File(failure.backupPath!).readAsString(), '{broken json');
    expect(await file.exists(), isFalse);
    expect(await store.readMap(), isNull);
  });

  test('quarantines a payload with the wrong shape', () async {
    await file.writeAsString(
      jsonEncode({
        '_format': VersionedLocalJsonStore.format,
        'schemaVersion': 1,
        'payload': <Object>[],
      }),
    );

    await expectLater(
      store.readMap(),
      throwsA(isA<LocalDataCorruptionException>()),
    );
    await expectLater(store.readMap(), completion(isNull));
  });

  test('preserves a future schema without reading or quarantining it',
      () async {
    final original = jsonEncode({
      '_format': VersionedLocalJsonStore.format,
      'schemaVersion': 99,
      'payload': {},
    });
    await file.writeAsString(original);

    expect(
      store.readMap,
      throwsA(
        isA<UnsupportedLocalSchemaVersionException>()
            .having((error) => error.storedVersion, 'storedVersion', 99)
            .having((error) => error.supportedVersion, 'supportedVersion', 1),
      ),
    );

    expect(await file.readAsString(), original);
    expect(
      directory.listSync().whereType<File>().map((item) => item.path),
      [file.path],
    );
  });

  test('refuses to overwrite a future schema through the write path', () async {
    final original = jsonEncode({
      '_format': VersionedLocalJsonStore.format,
      'formatVersion': 1,
      'schema': 'test.state',
      'schemaVersion': 99,
      'payload': {'future': true},
    });
    await file.writeAsString(original);

    await expectLater(
      store.writeMap({'future': false}),
      throwsA(isA<UnsupportedLocalSchemaVersionException>()),
    );

    expect(await file.readAsString(), original);
  });

  test('allows a fresh full snapshot save over a current file', () async {
    await file.writeAsString(jsonEncode({
      '_format': VersionedLocalJsonStore.format,
      'formatVersion': 1,
      'schema': 'test.state',
      'schemaVersion': 1,
      'revision': 1,
      'payload': {'value': 1},
    }));

    await store.writeMap({'value': 2});

    expect(await store.readMap(), {'value': 2});
  });

  test('rejects an unknown reserved format without rewriting it', () async {
    final original = jsonEncode({
      '_format': 'paperflow.local-json-v2',
      'schemaVersion': 99,
      'payload': {},
    });
    await file.writeAsString(original);

    await expectLater(
      store.readMap(),
      throwsA(isA<UnsupportedLocalStorageFormatException>()),
    );

    expect(await file.readAsString(), original);
    expect(
      directory.listSync().whereType<File>().map((item) => item.path),
      [file.path],
    );
  });

  test('migrates schema payloads one version at a time', () async {
    final migratingStore = VersionedLocalJsonStore(
      LocalJsonStore(fileName: 'unused.json', file: file),
      schemaId: 'test.state',
      schemaVersion: 3,
      migrations: {
        1: (payload) => {
              ...Map<String, dynamic>.from(payload as Map),
              'v2': true,
            },
        2: (payload) => {
              ...Map<String, dynamic>.from(payload as Map),
              'v3': true,
            },
      },
    );
    await file.writeAsString(jsonEncode({
      '_format': VersionedLocalJsonStore.format,
      'formatVersion': 1,
      'schema': 'test.state',
      'schemaVersion': 1,
      'payload': {'v1': true},
    }));

    expect(await migratingStore.readMap(), {
      'v1': true,
      'v2': true,
      'v3': true,
    });
    final migrated = jsonDecode(await file.readAsString()) as Map;
    expect(migrated['schemaVersion'], 3);
    expect(migrated['payload'], {
      'v1': true,
      'v2': true,
      'v3': true,
    });
  });

  test('supports an explicit storage envelope format migration', () async {
    final migratingStore = VersionedLocalJsonStore(
      LocalJsonStore(fileName: 'unused.json', file: file),
      schemaId: 'test.state',
      formatMigrations: {
        0: (envelope) => {
              ...envelope,
              'formatVersion': 1,
              'revision': 0,
            },
      },
    );
    await file.writeAsString(jsonEncode({
      '_format': VersionedLocalJsonStore.format,
      'formatVersion': 0,
      'schema': 'test.state',
      'schemaVersion': 1,
      'payload': {'value': true},
    }));

    expect(await migratingStore.readMap(), {'value': true});
  });

  test('serializes concurrent map updates from separate store instances',
      () async {
    final otherStore = VersionedLocalJsonStore(
      LocalJsonStore(fileName: 'unused.json', file: file),
      schemaId: 'test.state',
    );

    await Future.wait([
      store.updateMap((current) => {...?current, 'first': true}),
      otherStore.updateMap((current) => {...?current, 'second': true}),
    ]);

    expect(await store.readMap(), {'first': true, 'second': true});
  });

  test('rejects a stale full snapshot from another store instance', () async {
    await store.writeMap({'value': 1});
    final otherStore = VersionedLocalJsonStore(
      LocalJsonStore(fileName: 'unused.json', file: file),
      schemaId: 'test.state',
    );
    expect(await otherStore.readMap(), {'value': 1});

    await store.writeMap({'value': 2});

    await expectLater(
      otherStore.writeMap({'value': 3}),
      throwsA(isA<LocalConcurrentModificationException>()),
    );
    expect(await store.readMap(), {'value': 2});
  });

  test('normalizes an older envelope without format and revision fields',
      () async {
    await file.writeAsString(jsonEncode({
      '_format': VersionedLocalJsonStore.format,
      'schema': 'test.state',
      'schemaVersion': 1,
      'payload': {'value': true},
    }));

    expect(await store.readMap(), {'value': true});

    final normalized = jsonDecode(await file.readAsString()) as Map;
    expect(normalized['formatVersion'], 1);
    expect(normalized['revision'], 1);
  });

  test('restores a previous file left by an interrupted replacement', () async {
    final recovery = File('${file.path}.previous');
    await recovery.writeAsString(jsonEncode({'restored': true}));

    expect(await store.readMap(), {'restored': true});
    expect(await recovery.exists(), isFalse);
  });

  test('does not quarantine ordinary file system errors', () async {
    final parentFile = File(
      '${directory.path}${Platform.pathSeparator}not-a-directory',
    );
    await parentFile.writeAsString('occupied');
    final invalidTarget = File(
      '${parentFile.path}${Platform.pathSeparator}state.json',
    );
    final invalidStore = VersionedLocalJsonStore(
      LocalJsonStore(fileName: 'unused.json', file: invalidTarget),
      schemaId: 'test.state',
    );

    await expectLater(
      invalidStore.writeMap({'value': true}),
      throwsA(isA<LocalStorageException>()),
    );
    expect(
      directory
          .listSync()
          .whereType<File>()
          .where((item) => item.path.contains('.corrupt.')),
      isEmpty,
    );
  });
}
