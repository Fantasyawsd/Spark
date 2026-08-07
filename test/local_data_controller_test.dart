import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/local_data/data/in_memory_local_data_repository.dart';

void main() {
  test('coordinates clear callbacks and refreshes usage', () async {
    final repository = InMemoryLocalDataRepository(
      const LocalDataUsage(
        paperCacheBytes: 1024,
        chatBytes: 2048,
        businessDataBytes: 4096,
      ),
    );
    final before = <LocalDataClearTarget>[];
    final after = <LocalDataClearTarget>[];
    final controller = LocalDataController(
      repository: repository,
      beforeClear: (target) async => before.add(target),
      afterClear: (target) async => after.add(target),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.usage.totalBytes, 7168);

    expect(await controller.clearChats(), isTrue);
    expect(controller.usage.chatBytes, 0);
    expect(controller.usage.paperCacheBytes, 1024);
    expect(before, [LocalDataClearTarget.chats]);
    expect(after, [LocalDataClearTarget.chats]);

    expect(await controller.resetAllBusinessData(), isTrue);
    expect(controller.usage.totalBytes, 0);
    expect(before.last, LocalDataClearTarget.allBusinessData);
    expect(after.last, LocalDataClearTarget.allBusinessData);
  });

  test('reloads state and usage after a partially failed clear', () async {
    final repository = _PartiallyFailingLocalDataRepository();
    final after = <LocalDataClearTarget>[];
    final controller = LocalDataController(
      repository: repository,
      afterClear: (target) async => after.add(target),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(await controller.resetAllBusinessData(), isFalse);

    expect(after, [LocalDataClearTarget.allBusinessData]);
    expect(controller.usage.paperCacheBytes, 0);
    expect(controller.usage.chatBytes, 2048);
    expect(controller.error, '部分本地数据无法删除。');
  });
}

class _PartiallyFailingLocalDataRepository implements LocalDataRepository {
  var _usage = const LocalDataUsage(
    paperCacheBytes: 1024,
    chatBytes: 2048,
    businessDataBytes: 4096,
  );

  @override
  Future<LocalDataUsage> inspect() async => _usage;

  @override
  Future<void> clearChats() async {}

  @override
  Future<void> clearPaperCache() async {}

  @override
  Future<void> resetAllBusinessData() async {
    _usage = const LocalDataUsage(
      paperCacheBytes: 0,
      chatBytes: 2048,
      businessDataBytes: 0,
    );
    throw const LocalDataException('部分本地数据无法删除。');
  }
}
