import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

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
}
