import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/core/storage/local_json_store.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spark-ai-session-');
    file = File('${directory.path}${Platform.pathSeparator}sessions.json');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('restores cancelled assistant messages after repository recreation',
      () async {
    final first = FilePaperAiSessionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );
    await first.save('paper-1', const [
      PaperAiMessage(fromUser: true, content: '问题'),
      PaperAiMessage(
        fromUser: false,
        content: '部分回答',
        status: PaperAiMessageStatus.cancelled,
      ),
    ]);

    final restored = FilePaperAiSessionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );
    final messages = await restored.load('paper-1');

    expect(messages, hasLength(2));
    expect(messages.last.content, '部分回答');
    expect(messages.last.status, PaperAiMessageStatus.cancelled);
  });

  test('legacy messages without status remain complete', () async {
    await file.writeAsString('''
{"paper-1":{"messages":[{"fromUser":false,"content":"旧回答"}]}}
''');
    final repository = FilePaperAiSessionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    final messages = await repository.load('paper-1');

    expect(messages.single.status, PaperAiMessageStatus.complete);
  });

  test('emits changes after save and clear', () async {
    final repository = FilePaperAiSessionRepository(
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );
    var events = 0;
    final subscription = repository.changes.listen((_) => events++);

    await repository.save('paper-1', const [
      PaperAiMessage(fromUser: true, content: '问题'),
    ]);
    await pumpEventQueue();
    expect(events, 1);

    await repository.clear('paper-1');
    await pumpEventQueue();
    expect(events, 2);

    await subscription.cancel();
  });
}
