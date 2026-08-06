import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/core/storage/local_json_store.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spark-comments-');
    file = File('${directory.path}${Platform.pathSeparator}comments.json');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('restores comments after the repository is recreated', () async {
    final first = FilePaperCommentRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );
    final empty = await first.load('paper-1');
    expect(empty.hasStoredValue, isFalse);

    await first.save('paper-1', const [
      PaperCommentRecord(
        id: 'comment-1',
        paperId: 'paper-1',
        name: 'Alex Chen',
        initials: 'AC',
        time: '刚刚',
        location: '北京',
        body: 'persisted comment',
        likes: 3,
        isLocalUser: true,
        likedByLocalUser: true,
      ),
    ]);

    final restored = FilePaperCommentRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );
    final snapshot = await restored.load('paper-1');

    expect(snapshot.hasStoredValue, isTrue);
    expect(snapshot.comments.single.body, 'persisted comment');
    expect(snapshot.comments.single.likes, 3);
    expect(snapshot.comments.single.likedByLocalUser, isTrue);
  });

  test('reports malformed local data as a persistence error', () async {
    await file.writeAsString('{broken json');
    final repository = FilePaperCommentRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    expect(
      () => repository.load('paper-1'),
      throwsA(isA<PaperCommentPersistenceException>()),
    );
  });

  test('quarantines comments with invalid record fields', () async {
    await file.writeAsString(jsonEncode({
      'paper-1': [
        {
          'id': 'comment-1',
          'paperId': 'paper-1',
          'name': 'Alex Chen',
          'initials': 'AC',
          'time': '刚刚',
          'body': 'invalid likes',
          'likes': 'three',
        },
      ],
    }));
    final repository = FilePaperCommentRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    await expectLater(
      repository.load('paper-1'),
      throwsA(isA<PaperCommentPersistenceException>()),
    );

    expect(await file.exists(), isFalse);
    expect(
      directory
          .listSync()
          .whereType<File>()
          .where((item) => item.path.contains('.corrupt.')),
      hasLength(1),
    );
  });
}
