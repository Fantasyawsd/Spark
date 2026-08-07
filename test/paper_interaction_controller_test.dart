import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_interaction_controller.dart';
import 'package:spark/src/features/papers/domain/favorite_group.dart';
import 'package:spark/src/features/papers/domain/paper_interaction_repository.dart';

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

  test('interaction writes recover after an unexpected save failure', () async {
    final repository = _ControlledInteractionRepository()
      ..throwUnexpectedOnNextSave = true;
    final controller = PaperInteractionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    controller.toggleLike('paper-1');
    await expectLater(controller.flushPendingWrites(), completes);

    expect(controller.isLiked('paper-1'), isFalse);
    expect(controller.persistenceError, isNotNull);

    controller.toggleLike('paper-1');
    await expectLater(controller.flushPendingWrites(), completes);
    expect(controller.isLiked('paper-1'), isTrue);
    expect(repository.saveCalls, 2);
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

  test('single tap toggles only the default favorite group', () async {
    final controller = PaperInteractionController();
    addTearDown(controller.dispose);

    final customGroupId = controller.createFavoriteGroup('方法论文');
    controller.setFavoriteMembership(
      paperId: 'paper-1',
      groupId: customGroupId,
      selected: true,
    );
    controller.toggleSave('paper-1');

    expect(controller.isSaved('paper-1'), isTrue);
    expect(
      controller.favoriteGroupIdsForPaper('paper-1'),
      {defaultFavoriteGroupId, customGroupId},
    );

    controller.toggleSave('paper-1');
    expect(controller.isSaved('paper-1'), isTrue);
    expect(controller.favoriteGroupIdsForPaper('paper-1'), {customGroupId});
  });

  test('custom favorite groups persist rename, membership and deletion',
      () async {
    final repository = _ControlledInteractionRepository();
    final controller = PaperInteractionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    final groupId = controller.createFavoriteGroup('待读');
    controller.renameFavoriteGroup(groupId, '重点阅读');
    controller.setFavoriteMembership(
      paperId: 'paper-2',
      groupId: groupId,
      selected: true,
    );
    await controller.flushPendingWrites();

    expect(repository.snapshot.favoriteGroups.last.name, '重点阅读');
    expect(repository.snapshot.savedPaperIds, {'paper-2'});

    controller.deleteFavoriteGroup(groupId);
    await controller.flushPendingWrites();
    expect(controller.isSaved('paper-2'), isFalse);
    expect(
      controller.favoriteGroups.map((group) => group.id),
      [defaultFavoriteGroupId],
    );
  });
}

class _ControlledInteractionRepository implements PaperInteractionRepository {
  _ControlledInteractionRepository([PaperInteractionSnapshot? snapshot])
      : snapshot = snapshot ?? PaperInteractionSnapshot();

  PaperInteractionSnapshot snapshot;
  final Set<int> failSaveCalls = {};
  bool failNextSave = false;
  bool throwUnexpectedOnNextSave = false;
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
    if (throwUnexpectedOnNextSave) {
      throwUnexpectedOnNextSave = false;
      throw StateError('disk unavailable');
    }
    if (failNextSave || failSaveCalls.contains(_saveCalls)) {
      failNextSave = false;
      throw const PaperInteractionPersistenceException('保存失败');
    }
    this.snapshot = snapshot;
  }

  void completeLoad() => _loadCompleter?.complete();
}
