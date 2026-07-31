import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  group('PaperSearchController', () {
    late InMemoryPaperSearchHistoryRepository historyRepository;
    late PaperSearchController controller;

    setUp(() {
      historyRepository = InMemoryPaperSearchHistoryRepository(['Mamba']);
      controller = PaperSearchController(
        papers: const DemoPaperRepository().getAll(),
        historyRepository: historyRepository,
        debounceDuration: const Duration(milliseconds: 5),
      );
    });

    tearDown(() => controller.dispose());

    test('matches title, author, venue and topic without case sensitivity',
        () async {
      await controller.initialize();

      await controller.submitQuery('lOrA');
      expect(controller.results.first.id, 'lora-2021');
      expect(
        controller.results.map((paper) => paper.id),
        contains('qlora-2023'),
      );

      await controller.submitQuery('Tri Dao');
      expect(controller.results.single.id, 'mamba-2023');

      await controller.submitQuery('ICCV');
      expect(controller.results.single.id, 'segment-anything-2023');

      await controller.submitQuery('segmentation');
      expect(controller.results.single.id, 'segment-anything-2023');
    });

    test('debounces input and exposes an empty result state', () async {
      controller.updateQuery('LoRA');
      expect(controller.results, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.results.first.id, 'lora-2021');

      await controller.submitQuery('not-a-real-paper');
      expect(controller.results, isEmpty);
    });

    test('deduplicates, removes and clears persisted history', () async {
      await controller.initialize();
      await controller.submitQuery('mamba');

      expect(controller.history, ['mamba']);
      await controller.removeHistory('mamba');
      expect(await historyRepository.load(), isEmpty);

      await controller.submitQuery('LoRA');
      await controller.submitQuery('ICLR');
      await controller.clearHistory();
      expect(await historyRepository.load(), isEmpty);
    });
  });

  test('file search history survives repository recreation', () async {
    final directory =
        await Directory.systemTemp.createTemp('paperflow-search-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}history.json');

    await FilePaperSearchHistoryRepository(file: file).save(['LoRA', 'Mamba']);
    final restored = await FilePaperSearchHistoryRepository(file: file).load();

    expect(restored, ['LoRA', 'Mamba']);
  });
}
