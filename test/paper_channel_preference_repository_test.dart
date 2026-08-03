import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/core/storage/local_json_store.dart';

void main() {
  late Directory directory;
  late File file;
  late FilePaperChannelPreferenceRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('paperflow-channels-');
    file = File('${directory.path}${Platform.pathSeparator}channels.json');
    repository = FilePaperChannelPreferenceRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  PaperChannelPreferences subjectPreferences(List<(String, String)> subjects) {
    return PaperChannelPreferences(
      userChannels: [
        for (final (code, name) in subjects)
          UserPaperChannel(
            kind: PaperChannelKind.subject,
            id: code,
            displayName: name,
          ),
      ],
    );
  }

  test('loads empty preferences before any save', () async {
    expect((await repository.load()).userChannels, isEmpty);
  });

  test('persists channel additions and order across reloads', () async {
    await repository.save(subjectPreferences([
      ('cs.AI', '人工智能'),
      ('cs.LG', '机器学习'),
    ]));

    final loaded = await repository.load();
    expect(
      loaded.userChannels.map((channel) => channel.id).toList(),
      ['cs.AI', 'cs.LG'],
    );
    expect(loaded.userChannels.first.displayName, '人工智能');
    expect(loaded.userChannels.first.kind, PaperChannelKind.subject);
  });

  test('persists reorder and removal', () async {
    await repository.save(subjectPreferences([
      ('cs.AI', '人工智能'),
      ('cs.LG', '机器学习'),
    ]));
    await repository.save(subjectPreferences([
      ('cs.LG', '机器学习'),
    ]));

    final loaded = await repository.load();
    expect(
      loaded.userChannels.map((channel) => channel.id).toList(),
      ['cs.LG'],
    );
  });

  test('writes a versioned envelope with the channel preferences schema',
      () async {
    await repository.save(subjectPreferences([('cs.CL', '计算与语言')]));

    final envelope =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(envelope['_format'], 'paperflow.local-json');
    expect(envelope['schema'], 'papers.channel-preferences');
    expect(envelope['schemaVersion'], 1);
  });

  test('reports persistence errors for unknown channel kinds', () async {
    await file.writeAsString(jsonEncode({
      '_format': 'paperflow.local-json',
      'formatVersion': 1,
      'schema': 'papers.channel-preferences',
      'schemaVersion': 1,
      'revision': 1,
      'payload': {
        'userChannels': [
          {'kind': 'topic', 'id': 'cs.AI', 'displayName': '人工智能'},
        ],
      },
    }));

    await expectLater(
      repository.load(),
      throwsA(isA<PaperChannelPreferencePersistenceException>()),
    );
  });

  test('in-memory repository roundtrips preferences', () async {
    final inMemory = InMemoryPaperChannelPreferenceRepository();
    expect((await inMemory.load()).userChannels, isEmpty);

    await inMemory.save(subjectPreferences([('cs.CV', '计算机视觉与模式识别')]));
    expect(
      (await inMemory.load()).userChannels.single.storageKey,
      'subject:cs.CV',
    );
  });
}
