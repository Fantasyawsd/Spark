import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  test('restores and persists paper reading state', () async {
    final repository = InMemoryPaperReadingRepository(
      PaperReadingSnapshot(
        readPaperIds: const ['paper-1'],
        readLaterPaperIds: const ['paper-2'],
        historyPaperIds: const ['paper-2', 'paper-1'],
        tabIndices: const {'paper-1': 1},
        abstractScrollOffsets: const {'paper-1': 48.5},
        dwellMilliseconds: const {'paper-1': 1200},
      ),
    );
    final controller = PaperReadingController(repository: repository);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.initialized, isTrue);
    expect(controller.isRead('paper-1'), isTrue);
    expect(controller.isReadLater('paper-2'), isTrue);
    expect(controller.historyPaperIds, ['paper-2', 'paper-1']);
    expect(controller.tabIndex('paper-1'), 1);
    expect(controller.abstractScrollOffset('paper-1'), 48.5);
    expect(controller.dwellTime('paper-1'), const Duration(milliseconds: 1200));

    controller.recordOpened('paper-1');
    controller.toggleRead('paper-1');
    controller.toggleReadLater('paper-3');
    controller.selectTab('paper-3', 2);
    controller.saveAbstractScrollOffset('paper-3', 80.25);
    controller.addDwellTime('paper-3', const Duration(seconds: 2));
    await controller.flushPendingWrites();

    final restored = PaperReadingController(repository: repository);
    addTearDown(restored.dispose);
    await restored.initialize();

    expect(restored.historyPaperIds, ['paper-1', 'paper-2']);
    expect(restored.isRead('paper-1'), isFalse);
    expect(restored.isReadLater('paper-3'), isTrue);
    expect(restored.tabIndex('paper-3'), 2);
    expect(restored.abstractScrollOffset('paper-3'), 80.25);
    expect(restored.dwellTime('paper-3'), const Duration(seconds: 2));
  });

  test('keeps history unique and bounded', () async {
    final controller = PaperReadingController();
    addTearDown(controller.dispose);
    await controller.initialize();

    for (var index = 0;
        index < PaperReadingController.historyLimit + 5;
        index++) {
      controller.recordOpened('paper-$index');
    }
    controller.recordOpened('paper-50');

    expect(
      controller.historyPaperIds,
      hasLength(PaperReadingController.historyLimit),
    );
    expect(controller.historyPaperIds.first, 'paper-50');
    expect(
      controller.historyPaperIds.where((id) => id == 'paper-50'),
      hasLength(1),
    );
  });
}
