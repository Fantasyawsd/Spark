import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/core/storage/versioned_local_json_store.dart';
import 'package:spark/src/features/papers/application/paper_translation_service.dart';
import 'package:spark/src/features/papers/data/cache/paper_record_cache_policy.dart';
import 'package:spark/src/features/papers/data/file_paper_interaction_repository.dart';
import 'package:spark/src/features/papers/data/file_paper_preference_repository.dart';
import 'package:spark/src/features/papers/data/file_paper_translation_repository.dart';
import 'package:spark/src/features/papers/domain/favorite_group.dart';
import 'package:spark/src/features/papers/domain/paper_interaction_repository.dart';
import 'package:spark/src/features/papers/domain/paper_preference_repository.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spark-records-');
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
    expect(envelope['schemaVersion'], 2);
  });

  test('translation repository rejects malformed cached translations',
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

  test('translation repository persists freshness metadata', () async {
    final file = _file(directory, 'translation-records.json');
    final generatedAt = DateTime.utc(2026, 8, 7, 12);
    final repository = FilePaperTranslationRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
      clock: () => generatedAt,
    );
    final record = PaperTranslationRecord(
      paperId: 'paper-1',
      markdown: '中文翻译',
      inputFingerprint: '0123456789abcdef',
      promptVersion: paperTranslationPromptVersion,
      generatedAt: generatedAt,
    );

    await repository.save(record);
    final restored = await repository.load(record.paperId);

    expect(restored?.markdown, record.markdown);
    expect(restored?.inputFingerprint, record.inputFingerprint);
    expect(restored?.promptVersion, record.promptVersion);
    expect(restored?.generatedAt, generatedAt);
    final envelope = jsonDecode(await file.readAsString()) as Map;
    expect(envelope['schemaVersion'], 2);
  });

  test('translation load rejects a record after its TTL', () async {
    final file = _file(directory, 'translation-ttl.json');
    var now = DateTime.utc(2026, 8, 7, 12);
    final repository = FilePaperTranslationRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
      clock: () => now,
      policy: const PaperRecordCachePolicy(
        ttl: Duration(hours: 1),
        maxEntries: 10,
      ),
    );
    await repository.save(_translationRecord('paper-1', generatedAt: now));

    now = now.add(const Duration(hours: 1, microseconds: 1));

    expect(await repository.load('paper-1'), isNull);
  });

  test('translation save prunes expired and oldest records', () async {
    final file = _file(directory, 'translation-bounds.json');
    final now = DateTime.utc(2026, 8, 7, 12);
    final repository = FilePaperTranslationRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
      clock: () => now,
      policy: const PaperRecordCachePolicy(
        ttl: Duration(days: 1),
        maxEntries: 2,
      ),
    );

    await repository.save(
      _translationRecord(
        'expired',
        generatedAt: now.subtract(const Duration(days: 2)),
      ),
    );
    await repository.save(
      _translationRecord(
        'oldest',
        generatedAt: now.subtract(const Duration(hours: 2)),
      ),
    );
    await repository.save(
      _translationRecord(
        'middle',
        generatedAt: now.subtract(const Duration(hours: 1)),
      ),
    );
    await repository.save(_translationRecord('newest', generatedAt: now));

    final envelope = jsonDecode(await file.readAsString()) as Map;
    final payload = envelope['payload'] as Map;
    expect(payload.keys, containsAll(<String>['middle', 'newest']));
    expect(payload, isNot(contains('expired')));
    expect(payload, isNot(contains('oldest')));
    expect(payload, hasLength(2));
  });

  test('concurrent translation saves do not overwrite each other', () async {
    final file = _file(directory, 'translation-concurrent.json');
    final now = DateTime.utc(2026, 8, 7, 12);
    FilePaperTranslationRepository repository() {
      return FilePaperTranslationRepository(
        store: LocalJsonStore(fileName: 'unused.json', file: file),
        clock: () => now,
        policy: const PaperRecordCachePolicy(
          ttl: Duration(days: 1),
          maxEntries: 10,
        ),
      );
    }

    final first = repository();
    final second = repository();
    await Future.wait([
      first.save(_translationRecord('paper-1', generatedAt: now)),
      second.save(_translationRecord('paper-2', generatedAt: now)),
    ]);

    expect(await first.load('paper-1'), isNotNull);
    expect(await first.load('paper-2'), isNotNull);
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

  test('interaction repository migrates legacy saves into default favorites',
      () async {
    final file = _file(directory, 'legacy-interactions.json');
    await file.writeAsString(jsonEncode({
      '_format': VersionedLocalJsonStore.format,
      'formatVersion': 1,
      'schema': 'papers.interactions',
      'schemaVersion': 1,
      'revision': 3,
      'payload': {
        'likedPaperIds': <String>[],
        'savedPaperIds': ['paper-1'],
        'followedPaperIds': <String>[],
        'shareCountDeltas': <String, int>{},
      },
    }));
    final repository = FilePaperInteractionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    final snapshot = await repository.load();

    expect(snapshot.savedPaperIds, {'paper-1'});
    expect(snapshot.favoriteGroups.single.id, defaultFavoriteGroupId);
    expect(
      snapshot.favoritePaperIdsByGroup[defaultFavoriteGroupId],
      {'paper-1'},
    );
    final envelope = jsonDecode(await file.readAsString()) as Map;
    expect(envelope['schemaVersion'], 2);
    expect((envelope['payload'] as Map), isNot(contains('savedPaperIds')));
  });

  test('interaction repository restores custom favorite groups', () async {
    final file = _file(directory, 'grouped-interactions.json');
    final repository = FilePaperInteractionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );
    const customGroup = FavoriteGroup(id: 'methods', name: '方法论文');

    await repository.save(
      PaperInteractionSnapshot(
        favoriteGroups: const [customGroup],
        favoritePaperIdsByGroup: const {
          defaultFavoriteGroupId: {'paper-1'},
          'methods': {'paper-1', 'paper-2'},
        },
      ),
    );
    final restored = await FilePaperInteractionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    ).load();

    expect(restored.favoriteGroups.map((group) => group.name), [
      '默认收藏',
      '方法论文',
    ]);
    expect(restored.savedPaperIds, {'paper-1', 'paper-2'});
    expect(restored.favoritePaperIdsByGroup['methods'], {
      'paper-1',
      'paper-2',
    });
  });
}

File _file(Directory directory, String name) {
  return File('${directory.path}${Platform.pathSeparator}$name');
}

PaperTranslationRecord _translationRecord(
  String paperId, {
  required DateTime generatedAt,
}) {
  return PaperTranslationRecord(
    paperId: paperId,
    markdown: 'translation for $paperId',
    inputFingerprint: 'fingerprint-$paperId',
    promptVersion: paperTranslationPromptVersion,
    generatedAt: generatedAt,
  );
}
