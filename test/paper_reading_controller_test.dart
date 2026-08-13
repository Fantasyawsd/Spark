import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/papers/application/paper_reading_controller.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_reading_repository.dart';
import 'package:spark/src/features/papers/domain/paper_reading_repository.dart';

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

  test('replays mutations made while persisted state is loading', () async {
    final repository = _BlockingPaperReadingRepository();
    final controller = PaperReadingController(repository: repository);
    addTearDown(controller.dispose);

    final initialization = controller.initialize();
    controller.recordOpened('paper-new');
    controller.toggleRead('paper-1');
    controller.toggleReadLater('paper-2');
    controller.selectTab('paper-new', 2);
    controller.saveAbstractScrollOffset('paper-new', 64);
    controller.addDwellTime('paper-1', const Duration(milliseconds: 300));

    repository.completeLoad(
      PaperReadingSnapshot(
        readPaperIds: const ['paper-1'],
        readLaterPaperIds: const ['paper-2'],
        historyPaperIds: const ['paper-1'],
        dwellMilliseconds: const {'paper-1': 700},
      ),
    );
    await initialization;
    await controller.flushPendingWrites();

    expect(controller.isRead('paper-new'), isTrue);
    expect(controller.isRead('paper-1'), isFalse);
    expect(controller.isReadLater('paper-2'), isFalse);
    expect(controller.historyPaperIds, ['paper-new', 'paper-1']);
    expect(controller.tabIndex('paper-new'), 2);
    expect(controller.abstractScrollOffset('paper-new'), 64);
    expect(controller.dwellTime('paper-1'), const Duration(seconds: 1));
    expect(repository.savedSnapshots.last.historyPaperIds,
        ['paper-new', 'paper-1']);
  });

  test('persists startup mutations after the initial load fails', () async {
    final repository = _BlockingPaperReadingRepository();
    final controller = PaperReadingController(repository: repository);
    addTearDown(controller.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      final initialization = controller.initialize();
      controller.recordOpened('paper-new');
      controller.toggleReadLater('paper-later');
      repository.failLoad(
        const PaperReadingPersistenceException('读取失败'),
      );

      await initialization;
      await controller.flushPendingWrites();
    });

    expect(controller.initialized, isTrue);
    expect(controller.isRead('paper-new'), isTrue);
    expect(controller.isReadLater('paper-later'), isTrue);
    expect(repository.savedSnapshots, hasLength(1));
    expect(repository.savedSnapshots.single.readPaperIds, {'paper-new'});
    expect(
      repository.savedSnapshots.single.readLaterPaperIds,
      {'paper-later'},
    );
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperReadingLoad],
    );
  });

  test('unexpected reading save failures keep the queue usable and report',
      () async {
    final repository = _BlockingPaperReadingRepository()
      ..throwUnexpectedOnSave = true;
    final controller = PaperReadingController(repository: repository);
    addTearDown(controller.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      final initialization = controller.initialize();
      repository.completeLoad(PaperReadingSnapshot());
      await initialization;
      controller.recordOpened('paper-new');
      await controller.flushPendingWrites();
    });

    expect(controller.persistenceError, '阅读记录保存失败，请稍后重试。');
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperReadingSave],
    );
  });
}

class _BlockingPaperReadingRepository implements PaperReadingRepository {
  final _load = Completer<PaperReadingSnapshot>();
  final List<PaperReadingSnapshot> savedSnapshots = [];
  bool throwUnexpectedOnSave = false;

  void completeLoad(PaperReadingSnapshot snapshot) => _load.complete(snapshot);

  void failLoad(Object error) => _load.completeError(error);

  @override
  Future<PaperReadingSnapshot> load() => _load.future;

  @override
  Future<void> save(PaperReadingSnapshot snapshot) async {
    if (throwUnexpectedOnSave) {
      throwUnexpectedOnSave = false;
      throw StateError('private-reading-save');
    }
    savedSnapshots.add(snapshot);
  }
}
