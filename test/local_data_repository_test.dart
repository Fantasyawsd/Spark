import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/features/local_data/data/json_local_data_repository.dart';

void main() {
  test('inspects and clears local JSON stores by data category', () async {
    final directory = await Directory.systemTemp.createTemp(
      'spark-local-data-',
    );
    addTearDown(() => directory.delete(recursive: true));
    LocalJsonStore store(String name) => LocalJsonStore(
          fileName: name,
          file: File('${directory.path}${Platform.pathSeparator}$name'),
        );

    final paperCache = store('paper-cache.json');
    final chats = store('chats.json');
    final businessData = store('business.json');
    await paperCache.write({'papers': List.filled(12, 'paper')});
    await chats.write({'messages': List.filled(8, 'message')});
    await businessData.write({'saved': List.filled(4, 'paper-id')});
    final repository = JsonLocalDataRepository(
      paperCacheStores: [paperCache],
      chatStores: [chats],
      businessDataStores: [businessData],
    );

    final initial = await repository.inspect();
    expect(initial.paperCacheBytes, greaterThan(0));
    expect(initial.chatBytes, greaterThan(0));
    expect(initial.businessDataBytes, greaterThan(0));
    expect(
      initial.totalBytes,
      initial.paperCacheBytes + initial.chatBytes + initial.businessDataBytes,
    );

    await repository.clearPaperCache();
    final afterPaperClear = await repository.inspect();
    expect(afterPaperClear.paperCacheBytes, 0);
    expect(afterPaperClear.chatBytes, initial.chatBytes);
    expect(afterPaperClear.businessDataBytes, initial.businessDataBytes);

    await repository.clearChats();
    final afterChatClear = await repository.inspect();
    expect(afterChatClear.chatBytes, 0);
    expect(afterChatClear.businessDataBytes, initial.businessDataBytes);

    await chats.write({
      'messages': ['new message']
    });
    expect((await repository.inspect()).chatBytes, greaterThan(0));

    await repository.resetAllBusinessData();
    expect((await repository.inspect()).totalBytes, 0);
  });

  test('counts and clears only managed recovery artifacts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'spark-local-data-artifacts-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}paper-cache.json',
    );
    final store = LocalJsonStore(fileName: 'unused.json', file: file);
    final recovery = File('${file.path}.previous');
    final managedFiles = [
      file,
      File('${file.path}.corrupt.123'),
      File('${file.path}.tmp.42.456.0'),
    ];
    for (final managedFile in managedFiles) {
      await managedFile.writeAsString('12345');
    }
    final unrelated = File('${file.path}.backup');
    await unrelated.writeAsString('keep');
    final repository = JsonLocalDataRepository(
      paperCacheStores: [store],
      chatStores: const [],
      businessDataStores: const [],
    );

    expect((await repository.inspect()).paperCacheBytes, 15);

    await recovery.writeAsString('12345');

    await repository.clearPaperCache();

    for (final managedFile in [...managedFiles, recovery]) {
      expect(await managedFile.exists(), isFalse);
    }
    expect(await unrelated.readAsString(), 'keep');
    expect((await repository.inspect()).paperCacheBytes, 0);
  });
}
