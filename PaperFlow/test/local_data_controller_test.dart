import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

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
}
