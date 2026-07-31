import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  group('PaperController', () {
    late PaperController controller;

    setUp(() {
      controller = PaperController(const DemoPaperRepository());
    });

    tearDown(() {
      controller.dispose();
    });

    test('exposes stable paper identities', () {
      final ids = controller.papers.map((paper) => paper.id).toSet();

      expect(controller.papers, hasLength(6));
      expect(ids, hasLength(controller.papers.length));
    });

    test('opening a grid item selects it and restores feed mode', () {
      controller.toggleGridMode();
      expect(controller.gridMode, isTrue);

      controller.openPaper(1);

      expect(controller.currentPaperIndex, 1);
      expect(controller.papers[1].id, 'mamba-2023');
      expect(controller.gridMode, isFalse);
    });

    test('shares like and save state across presentations', () {
      final paperId = controller.papers[1].id;

      controller.toggleLike(paperId);
      controller.toggleSave(paperId);

      expect(controller.isLiked(paperId), isTrue);
      expect(controller.isSaved(paperId), isTrue);

      controller.toggleLike(paperId);
      controller.toggleSave(paperId);

      expect(controller.isLiked(paperId), isFalse);
      expect(controller.isSaved(paperId), isFalse);
    });

    test('owns selected and extra topic state', () {
      controller.setExtraCategories(['AI Agent', '机器人']);
      controller.selectCategory(5);

      expect(controller.categories.last, '机器人');
      expect(controller.categories[5], 'AI Agent');
      expect(controller.categoryIndex, 5);
    });
  });
}
