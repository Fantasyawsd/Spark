import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  test('latest failed interaction write rolls optimistic state back', () async {
    final repository = _ControlledInteractionRepository()..failNextSave = true;
    final controller = PaperInteractionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    controller.toggleLike('paper-1');
    expect(controller.isLiked('paper-1'), isTrue);

    await controller.flushPendingWrites();

    expect(controller.isLiked('paper-1'), isFalse);
    expect(controller.persistenceError, '保存失败');
    expect(controller.errorRevision, 1);
  });

  test('an older failed write does not overwrite a newer interaction',
      () async {
    final repository = _ControlledInteractionRepository()..failSaveCalls.add(1);
    final controller = PaperInteractionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    controller.toggleLike('paper-1');
    controller.toggleSave('paper-1');
    await controller.flushPendingWrites();

    expect(controller.isLiked('paper-1'), isTrue);
    expect(controller.isSaved('paper-1'), isTrue);
    expect(repository.snapshot.likedPaperIds, contains('paper-1'));
    expect(repository.snapshot.savedPaperIds, contains('paper-1'));
    expect(controller.persistenceError, isNull);
  });

  test('interaction during delayed load merges with persisted state', () async {
    final repository = _ControlledInteractionRepository(
      PaperInteractionSnapshot(
        likedPaperIds: const ['persisted-like'],
        savedPaperIds: const ['persisted-save'],
      ),
    )..holdLoad = true;
    final controller = PaperInteractionController(repository: repository);
    addTearDown(controller.dispose);

    final initialization = controller.initialize();
    controller.toggleLike('new-like');
    controller.toggleSave('new-save');

    expect(controller.isLiked('new-like'), isTrue);
    expect(repository.saveCalls, 0);

    repository.completeLoad();
    await initialization;
    await controller.flushPendingWrites();

    expect(controller.isLiked('persisted-like'), isTrue);
    expect(controller.isLiked('new-like'), isTrue);
    expect(controller.isSaved('persisted-save'), isTrue);
    expect(controller.isSaved('new-save'), isTrue);
    expect(repository.snapshot.likedPaperIds, {
      'persisted-like',
      'new-like',
    });
    expect(repository.snapshot.savedPaperIds, {
      'persisted-save',
      'new-save',
    });
  });
}

class _ControlledInteractionRepository implements PaperInteractionRepository {
  _ControlledInteractionRepository([PaperInteractionSnapshot? snapshot])
      : snapshot = snapshot ?? PaperInteractionSnapshot();

  PaperInteractionSnapshot snapshot;
  final Set<int> failSaveCalls = {};
  bool failNextSave = false;
  bool holdLoad = false;
  int _saveCalls = 0;
  Completer<void>? _loadCompleter;

  int get saveCalls => _saveCalls;

  @override
  Future<PaperInteractionSnapshot> load() async {
    if (holdLoad) {
      _loadCompleter = Completer<void>();
      await _loadCompleter!.future;
      holdLoad = false;
    }
    return snapshot;
  }

  @override
  Future<void> save(PaperInteractionSnapshot snapshot) async {
    _saveCalls++;
    if (failNextSave || failSaveCalls.contains(_saveCalls)) {
      failNextSave = false;
      throw const PaperInteractionPersistenceException('保存失败');
    }
    this.snapshot = snapshot;
  }

  void completeLoad() => _loadCompleter?.complete();
}
