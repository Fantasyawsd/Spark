import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  group('PaperController', () {
    late PaperController controller;

    setUp(() {
      controller = PaperController(const ArxivSeedRepository());
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
      expect(controller.papers[1].id, '2404.01356');
      expect(controller.gridMode, isFalse);
    });

    test('opening a search result resets filters and selects its paper', () {
      controller.selectTopic(3);
      controller.toggleGridMode();

      controller.openPaperById('2404.01356');

      expect(controller.primaryCategoryIndex, 0);
      expect(controller.topicIndex, 0);
      expect(controller.papers[controller.currentPaperIndex].id, '2404.01356');
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

    test('owns primary category and topic state', () {
      controller.selectTopic(3);

      expect(controller.topicIndex, 3);
      expect(controller.categories[controller.topicIndex], 'CV');
      expect(controller.papers, hasLength(1));
      expect(controller.papers.single.topics, contains('cs.CV'));
    });

    test('following feed only exposes followed papers', () {
      final followed = controller.papers[2];

      controller.toggleFollow(followed.id);
      controller.selectPrimaryCategory(1);

      expect(controller.papers.map((paper) => paper.id), [followed.id]);
      expect(controller.isFollowed(followed.id), isTrue);

      controller.toggleFollow(followed.id);
      expect(controller.papers, isEmpty);
    });

    test('latest feed orders papers by publication date', () {
      controller.selectPrimaryCategory(2);

      final dates =
          controller.papers.map((paper) => paper.publishedAt).toList();
      for (var index = 1; index < dates.length; index++) {
        expect(dates[index - 1]!.isBefore(dates[index]!), isFalse);
      }
    });

    test('restores the last paper position for each filter', () {
      controller.selectPaper(2);
      controller.selectTopic(3);
      controller.selectTopic(0);

      expect(controller.currentPaperIndex, 2);
    });

    test('loads real arXiv seed records instead of demo records', () {
      expect(controller.papers, hasLength(6));
      expect(
          controller.papers.every((paper) => paper.source == 'arxiv'), isTrue);
      expect(controller.papers.first.arxivId, '2402.06734');
      expect(
          controller.papers.first.paperUrl, 'https://arxiv.org/abs/2402.06734');
    });

    test('exposes structured related papers with valid local targets', () {
      final ids = controller.papers.map((paper) => paper.id).toSet();

      expect(controller.papers.every((paper) => paper.relatedPapers.isNotEmpty),
          isTrue);
      for (final paper in controller.papers) {
        expect(
          paper.relatedPapers.every(
            (related) => ids.contains(related.id) && related.id != paper.id,
          ),
          isTrue,
        );
      }
    });

    test('restores persisted interaction state after recreation', () async {
      final repository = InMemoryPaperInteractionRepository();
      final first = PaperController(
        const ArxivSeedRepository(),
        interactionRepository: repository,
      );
      final paperId = first.papers.first.id;

      first.toggleLike(paperId);
      first.toggleSave(paperId);
      first.toggleFollow(paperId);
      await first.interactions.flushPendingWrites();
      first.dispose();

      final restored = PaperController(
        const ArxivSeedRepository(),
        interactionRepository: repository,
      );
      await restored.initialize();
      addTearDown(restored.dispose);

      expect(restored.isLiked(paperId), isTrue);
      expect(restored.isSaved(paperId), isTrue);
      expect(restored.isFollowed(paperId), isTrue);
    });

    test('serializes rapid interaction writes in their final order', () async {
      final repository = InMemoryPaperInteractionRepository();
      final persisted = PaperController(
        const ArxivSeedRepository(),
        interactionRepository: repository,
      );
      final paperId = persisted.papers.first.id;

      persisted.toggleLike(paperId);
      persisted.toggleLike(paperId);
      persisted.toggleLike(paperId);
      await persisted.interactions.flushPendingWrites();
      persisted.dispose();

      final restored = PaperController(
        const ArxivSeedRepository(),
        interactionRepository: repository,
      );
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(restored.isLiked(paperId), isTrue);
    });

    test('persists local share count deltas', () async {
      final repository = InMemoryPaperInteractionRepository();
      final first = PaperController(
        const ArxivSeedRepository(),
        interactionRepository: repository,
      );
      final paperId = first.papers.first.id;

      first.recordShare(paperId);
      first.recordShare(paperId);
      await first.interactions.flushPendingWrites();
      first.dispose();

      final restored = PaperController(
        const ArxivSeedRepository(),
        interactionRepository: repository,
      );
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(restored.shareCountDelta(paperId), 2);
    });

    test('restores custom topics after recreation', () async {
      final repository = InMemoryPaperPreferenceRepository();
      final first = PaperController(
        const ArxivSeedRepository(),
        preferenceRepository: repository,
      );

      first.setExtraCategories(['AI 安全', '机器人']);
      await first.feed.flushPreferenceWrites();
      first.dispose();

      final restored = PaperController(
        const ArxivSeedRepository(),
        preferenceRepository: repository,
      );
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(restored.extraCategories, ['AI 安全', '机器人']);
    });

    test('restores the selected filter and paper position after recreation',
        () async {
      final repository = InMemoryPaperPreferenceRepository();
      final first = PaperController(
        const ArxivSeedRepository(),
        preferenceRepository: repository,
      );

      first.selectPaper(2);
      first.selectPrimaryCategory(2);
      first.selectPaper(1);
      await first.feed.flushPreferenceWrites();
      first.dispose();

      final restored = PaperController(
        const ArxivSeedRepository(),
        preferenceRepository: repository,
      );
      await restored.initialize();
      addTearDown(restored.dispose);

      expect(restored.primaryCategoryIndex, 2);
      expect(restored.currentPaperIndex, 1);

      restored.selectPrimaryCategory(0);
      expect(restored.currentPaperIndex, 2);
    });

    test('exposes a barrier for active catalog writes', () async {
      final catalog = _BlockingPaperCatalogRepository();
      final controller = PaperController(
        const ArxivSeedRepository(),
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);

      final refresh = controller.feed.refreshCatalog();
      var barrierCompleted = false;
      final barrier = controller.feed.flushCatalogOperations().then(
            (_) => barrierCompleted = true,
          );
      await Future<void>.delayed(Duration.zero);
      expect(barrierCompleted, isFalse);

      catalog.complete();
      await Future.wait([refresh, barrier]);
      expect(barrierCompleted, isTrue);
    });

    test('sends selected recommendation topics to the remote catalog',
        () async {
      final catalog = _RecordingPaperCatalogRepository();
      final controller = PaperController(
        const ArxivSeedRepository(),
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(
        catalog.queries.single.category,
        'cs.CL|cs.AI|cs.CV|cs.DC|cs.OS|cs.PF|math.OC|math.ST|q-bio.QM|q-bio.BM',
      );

      controller.selectTopic(1);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries.last.category, 'cs.CL|cs.AI');

      controller.selectPrimaryCategory(2);
      await controller.feed.flushCatalogOperations();
      expect(
        catalog.queries.last.category,
        'cs.CL|cs.AI|cs.CV|cs.DC|cs.OS|cs.PF|math.OC|math.ST|q-bio.QM|q-bio.BM',
      );
    });

    test('topic refresh keeps previously loaded papers available to following',
        () async {
      final catalog = _RecordingPaperCatalogRepository();
      final controller = PaperController(
        const ArxivSeedRepository(),
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);
      final followed = controller.feed.allPapers.first;

      await controller.initialize();
      controller.toggleFollow(followed.id);
      controller.selectTopic(1);
      await controller.feed.flushCatalogOperations();
      controller.selectPrimaryCategory(1);

      expect(controller.papers.map((paper) => paper.id), contains(followed.id));
    });

    test('prefetches and deduplicates the next page before the buffer ends',
        () async {
      final catalog = _PagedPaperCatalogRepository(
        firstPage: List.generate(20, (index) => _catalogPaper('p$index')),
        secondPage: List.generate(
          20,
          (index) => _catalogPaper('p${index + 15}'),
        ),
      );
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
      );
      addTearDown(feed.dispose);

      await feed.initializeCatalog();
      expect(feed.papers, hasLength(20));

      feed.selectPaper(9);
      await feed.flushCatalogOperations();

      expect(catalog.queries.map((query) => query.offset), [0, 20]);
      expect(feed.papers, hasLength(35));
      expect(feed.papers.map((paper) => paper.id).toSet(), hasLength(35));
    });

    test('refresh prepends unseen papers without discarding the buffer',
        () async {
      final catalog = _PagedPaperCatalogRepository(
        firstPage: List.generate(20, (index) => _catalogPaper('p$index')),
      );
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
      );
      addTearDown(feed.dispose);

      await feed.initializeCatalog();
      catalog.firstPage = [
        _catalogPaper('new-paper'),
        _catalogPaper('p0', title: 'Updated paper'),
      ];

      await feed.refreshCatalog();

      expect(feed.papers.first.id, 'new-paper');
      expect(feed.papers[1].title, 'Updated paper');
      expect(feed.papers, hasLength(21));
      expect(
        feed.papers.where((paper) => paper.id == 'p0'),
        hasLength(1),
      );
    });
  });
}

class _RecordingPaperCatalogRepository implements PaperCatalogRepository {
  final List<PaperFeedQuery> queries = [];

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    queries.add(query);
    return PaperPage(papers: const [], source: PaperPageSource.remote);
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

class _BlockingPaperCatalogRepository implements PaperCatalogRepository {
  final _feed = Completer<PaperPage>();

  void complete() {
    _feed.complete(
      PaperPage(papers: const [], source: PaperPageSource.remote),
    );
  }

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) => _feed.future;

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

class _PagedPaperCatalogRepository implements PaperCatalogRepository {
  _PagedPaperCatalogRepository({
    required this.firstPage,
    this.secondPage = const [],
  });

  List<Paper> firstPage;
  List<Paper> secondPage;
  final List<PaperFeedQuery> queries = [];

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    queries.add(query);
    if (query.offset == 0) {
      return PaperPage(
        papers: firstPage,
        source: PaperPageSource.remote,
        nextOffset: secondPage.isEmpty ? null : 20,
      );
    }
    return PaperPage(
      papers: secondPage,
      source: PaperPageSource.remote,
    );
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

Paper _catalogPaper(String id, {String? title}) => Paper(
      id: id,
      venue: 'arXiv',
      title: title ?? 'Paper $id',
      authors: const ['Researcher'],
      firstAffiliation: 'Research Lab',
      topics: const ['cs.AI'],
      abstractText: 'Abstract for $id.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
      publishedAt: DateTime.utc(2026, 1, 1),
      source: 'arxiv',
    );
