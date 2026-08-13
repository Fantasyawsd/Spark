import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/papers/application/paper_comment_controller.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_comment_repository.dart';
import 'package:spark/src/features/papers/domain/paper_comment_repository.dart';

void main() {
  test('comments update counts, sorting and persisted state', () async {
    final repository = InMemoryPaperCommentRepository();
    final controller = PaperCommentController(repository: repository);
    addTearDown(controller.dispose);

    await controller.loadPaper('paper-1');
    await controller.addComment('paper-1', 'first');
    final firstId = controller.commentsFor('paper-1').single.id;
    await controller.addComment('paper-1', 'reply', parentId: firstId);
    await controller.addComment('paper-1', 'second');
    final secondId = controller
        .commentsFor('paper-1')
        .firstWhere((comment) => comment.body == 'second')
        .id;

    controller.toggleLike('paper-1', firstId);
    controller.setSort('paper-1', PaperCommentSort.hottest);

    expect(controller.commentCount('paper-1'), 3);
    expect(controller.rootCommentCount('paper-1'), 2);
    expect(controller.commentsFor('paper-1').first.id, firstId);

    controller.deleteComment('paper-1', firstId);
    await controller.flushPendingWrites();

    expect(controller.commentCount('paper-1'), 1);
    expect(controller.commentsFor('paper-1').single.id, secondId);

    final restored = PaperCommentController(repository: repository);
    addTearDown(restored.dispose);
    await restored.loadPaper('paper-1');
    expect(restored.commentCount('paper-1'), 1);
    expect(restored.commentsFor('paper-1').single.body, 'second');
  });

  test('comment send exposes progress and rejects duplicate submissions',
      () async {
    final repository = _ControlledCommentRepository()..holdSaves = true;
    final controller = PaperCommentController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadPaper('paper-1');

    final firstSend = controller.addComment('paper-1', 'first');
    await Future<void>.delayed(Duration.zero);

    expect(controller.sendStatusFor('paper-1'), PaperCommentSendStatus.sending);
    expect(await controller.addComment('paper-1', 'duplicate'), isFalse);
    expect(controller.commentCount('paper-1'), 1);

    repository.completeSave();
    expect(await firstSend, isTrue);
    expect(controller.sendStatusFor('paper-1'), PaperCommentSendStatus.idle);
  });

  test('failed comment send rolls back and remains retryable', () async {
    final repository = _ControlledCommentRepository()..failNextSave = true;
    final controller = PaperCommentController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadPaper('paper-1');
    final events = <SparkDiagnosticEvent>[];

    expect(
      await SparkDiagnostics.runWithSink(
        events.add,
        () => controller.addComment('paper-1', 'first'),
      ),
      isFalse,
    );
    expect(controller.commentsFor('paper-1'), isEmpty);
    expect(controller.sendStatusFor('paper-1'), PaperCommentSendStatus.failed);
    expect(controller.persistenceErrorFor('paper-1'), '保存评论失败');
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCommentsSave],
    );

    expect(await controller.addComment('paper-1', 'first'), isTrue);
    expect(controller.commentsFor('paper-1').single.body, 'first');
    expect(controller.sendStatusFor('paper-1'), PaperCommentSendStatus.idle);
    expect(controller.persistenceErrorFor('paper-1'), isNull);
  });

  test('comment writes recover after an unexpected save failure', () async {
    final repository = _ControlledCommentRepository()
      ..throwUnexpectedOnNextSave = true;
    final controller = PaperCommentController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadPaper('paper-1');
    final events = <SparkDiagnosticEvent>[];

    expect(
      await SparkDiagnostics.runWithSink(
        events.add,
        () => controller.addComment('paper-1', 'first'),
      ),
      isFalse,
    );
    expect(controller.commentsFor('paper-1'), isEmpty);
    expect(controller.persistenceErrorFor('paper-1'), isNotNull);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCommentsSave],
    );

    expect(await controller.addComment('paper-1', 'second'), isTrue);
    expect(controller.commentsFor('paper-1').single.body, 'second');
    expect(repository.saveCalls, 2);
    expect(controller.persistenceErrorFor('paper-1'), isNull);
  });

  test('a successful write for another paper does not clear its error',
      () async {
    final repository = _ControlledCommentRepository()..failNextSave = true;
    final controller = PaperCommentController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize(['paper-1', 'paper-2']);

    expect(await controller.addComment('paper-1', 'first'), isFalse);
    expect(await controller.addComment('paper-2', 'second'), isTrue);

    expect(controller.persistenceErrorFor('paper-1'), '保存评论失败');
    expect(controller.persistenceErrorFor('paper-2'), isNull);
  });

  test('a load failure cannot overwrite unknown stored comments', () async {
    final repository = _ControlledCommentRepository()..failNextLoad = true;
    final controller = PaperCommentController(repository: repository);
    addTearDown(controller.dispose);
    final events = <SparkDiagnosticEvent>[];

    expect(
      await SparkDiagnostics.runWithSink(
        events.add,
        () => controller.addComment('paper-1', 'first'),
      ),
      isFalse,
    );

    expect(controller.commentsFor('paper-1'), isEmpty);
    expect(controller.persistenceErrorFor('paper-1'), '读取评论失败');
    expect(repository.saveCalls, 0);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperCommentsLoad],
    );
  });
}

class _ControlledCommentRepository implements PaperCommentRepository {
  final Map<String, List<PaperCommentRecord>> _comments = {};
  bool failNextSave = false;
  bool throwUnexpectedOnNextSave = false;
  bool failNextLoad = false;
  bool holdSaves = false;
  int saveCalls = 0;
  Completer<void>? _saveCompleter;

  @override
  Future<PaperCommentSnapshot> load(String paperId) async {
    if (failNextLoad) {
      failNextLoad = false;
      throw const PaperCommentPersistenceException('读取评论失败');
    }
    final comments = _comments[paperId];
    return PaperCommentSnapshot(
      comments: List.unmodifiable(comments ?? const []),
      hasStoredValue: comments != null,
    );
  }

  @override
  Future<void> save(String paperId, List<PaperCommentRecord> comments) async {
    saveCalls++;
    if (throwUnexpectedOnNextSave) {
      throwUnexpectedOnNextSave = false;
      throw StateError('disk unavailable');
    }
    if (failNextSave) {
      failNextSave = false;
      throw const PaperCommentPersistenceException('保存评论失败');
    }
    if (holdSaves) {
      _saveCompleter = Completer<void>();
      await _saveCompleter!.future;
      holdSaves = false;
    }
    _comments[paperId] = List.of(comments);
  }

  void completeSave() => _saveCompleter?.complete();
}
