import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/papers/application/paper_controller.dart';
import 'package:spark/src/features/papers/application/paper_feed_controller.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_channel_preference_repository.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_interaction_repository.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_preference_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';
import 'package:spark/src/features/papers/domain/paper_channel.dart';
import 'package:spark/src/features/papers/domain/paper_preference_repository.dart';
import 'package:spark/src/features/papers/domain/paper_time_range.dart';

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

    test('opening a search result resets channels and selects its paper',
        () async {
      await controller.saveUserChannels([
        const UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.CV',
          displayName: '计算机视觉与模式识别',
        ),
      ]);
      controller.selectChannel(3);
      controller.toggleGridMode();

      controller.openPaperById('2404.01356');

      expect(controller.channelIndex, 0);
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

    test('user subject channels filter papers by arXiv subjects', () async {
      await controller.saveUserChannels([
        const UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.CV',
          displayName: '计算机视觉与模式识别',
        ),
      ]);

      controller.selectChannel(3);

      expect(controller.channelIndex, 3);
      expect(controller.papers, hasLength(1));
      expect(controller.papers.single.subjects, contains('cs.CV'));
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

    test('restores the last paper position for each channel', () async {
      await controller.saveUserChannels([
        const UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.AI',
          displayName: '人工智能',
        ),
      ]);
      controller.selectPaper(2);
      controller.selectChannel(3);
      controller.selectChannel(0);

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

    test('restores user channels and selection after recreation', () async {
      final repository = InMemoryPaperChannelPreferenceRepository();
      final first = PaperController(
        const ArxivSeedRepository(),
        channelPreferenceRepository: repository,
      );

      await first.saveUserChannels(const [
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.AI',
          displayName: '人工智能',
        ),
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.LG',
          displayName: '机器学习',
        ),
      ]);
      first.selectChannel(3);
      await first.feed.flushChannelPreferenceWrites();
      first.dispose();

      final restored = PaperController(
        const ArxivSeedRepository(),
        channelPreferenceRepository: repository,
      );
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(
        restored.userChannels.map((channel) => channel.id).toList(),
        ['cs.AI', 'cs.LG'],
      );
      expect(restored.channelIndex, 3);
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

    test('finishes pending preference initialization safely after dispose',
        () async {
      final preferences = _BlockingPaperPreferenceRepository();
      final feed = PaperFeedController.fromPapers(
        const [],
        preferenceRepository: preferences,
      );

      final initialization = feed.initializePreferences();
      feed.dispose();
      preferences.complete(PaperPreferences(
        timeRanges: const {'fixed:recommended': 'last-7-days'},
      ));

      await expectLater(initialization, completes);
    });

    test('preference writes recover after an unexpected save failure',
        () async {
      final preferences = _FlakyPaperPreferenceRepository();
      final feed = PaperFeedController.fromPapers(
        [_catalogPaper('paper-1')],
        preferenceRepository: preferences,
      );
      addTearDown(feed.dispose);

      feed.selectTimeRange(const PaperTimeRange.last7Days());
      await expectLater(feed.flushPreferenceWrites(), completes);
      expect(feed.preferenceError, isNotNull);

      feed.selectTimeRange(const PaperTimeRange.last30Days());
      await expectLater(feed.flushPreferenceWrites(), completes);
      expect(preferences.saveCalls, 2);
      expect(feed.preferenceError, isNull);
    });

    test('sends the selected channel category to the remote catalog', () async {
      final catalog = _RecordingPaperCatalogRepository();
      final controller = PaperController(
        const ArxivSeedRepository(),
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(
        catalog.queries.single.category,
        'cs.AI|cs.AR|cs.CC|cs.CE|cs.CG|cs.CL|cs.CR|cs.CV|cs.CY|cs.DB|cs.DC|cs.DL|cs.DM|cs.DS|cs.ET|cs.FL|cs.GL|cs.GR|cs.GT|cs.HC|cs.IR|cs.IT|cs.LG|cs.LO|cs.MA|cs.MM|cs.MS|cs.NA|cs.NE|cs.NI|cs.OH|cs.OS|cs.PF|cs.PL|cs.RO|cs.SC|cs.SD|cs.SE|cs.SI|cs.SY',
      );

      await controller.saveUserChannels(const [
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.CL',
          displayName: '计算与语言',
        ),
      ]);
      controller.selectChannel(3);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries.last.category, 'cs.CL');

      controller.selectPrimaryCategory(2);
      await controller.feed.flushCatalogOperations();
      expect(
        catalog.queries.last.category,
        'cs.AI|cs.AR|cs.CC|cs.CE|cs.CG|cs.CL|cs.CR|cs.CV|cs.CY|cs.DB|cs.DC|cs.DL|cs.DM|cs.DS|cs.ET|cs.FL|cs.GL|cs.GR|cs.GT|cs.HC|cs.IR|cs.IT|cs.LG|cs.LO|cs.MA|cs.MM|cs.MS|cs.NA|cs.NE|cs.NI|cs.OH|cs.OS|cs.PF|cs.PL|cs.RO|cs.SC|cs.SD|cs.SE|cs.SI|cs.SY',
      );
    });

    test('keeps and persists a time range per channel', () async {
      final preferences = InMemoryPaperPreferenceRepository();
      final channels = InMemoryPaperChannelPreferenceRepository();
      final catalog = _RecordingPaperCatalogRepository();
      final first = PaperController(
        const ArxivSeedRepository(),
        preferenceRepository: preferences,
        channelPreferenceRepository: channels,
        catalogRepository: catalog,
      );
      addTearDown(first.dispose);

      await first.initialize();
      first.feed.selectTimeRange(const PaperTimeRange.last7Days());
      await first.feed.flushCatalogOperations();
      await first.saveUserChannels(const [
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.CL',
          displayName: '计算与语言',
        ),
      ]);
      first.selectChannel(3);
      first.feed.selectTimeRange(const PaperTimeRange.last30Days());
      await first.feed.flushCatalogOperations();
      await first.feed.flushPreferenceWrites();
      await first.feed.flushChannelPreferenceWrites();

      expect(catalog.queries.last.timeRange.storageKey, 'last-30-days');
      first.selectChannel(0);
      expect(first.feed.timeRange.storageKey, 'last-7-days');

      final restored = PaperController(
        const ArxivSeedRepository(),
        preferenceRepository: preferences,
        channelPreferenceRepository: channels,
      );
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(restored.feed.timeRange.storageKey, 'last-7-days');
      restored.selectChannel(3);
      expect(restored.feed.timeRange.storageKey, 'last-30-days');
    });

    test('applies the selected time range to recommended fallback papers', () {
      final now = DateTime.now();
      final feed = PaperFeedController.fromPapers([
        _catalogPaper(
          'outside-range',
          publishedAt: now.subtract(const Duration(days: 8)),
        ),
        _catalogPaper(
          'inside-range',
          publishedAt: now.subtract(const Duration(days: 2)),
        ),
      ]);
      addTearDown(feed.dispose);

      feed.selectTimeRange(const PaperTimeRange.last7Days());

      expect(feed.papers.map((paper) => paper.id), ['inside-range']);
    });

    test('switching back to loaded channels does not refetch', () async {
      final catalog = _RecordingPaperCatalogRepository();
      final controller = PaperController(
        const ArxivSeedRepository(),
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(catalog.queries, hasLength(1));

      await controller.saveUserChannels(const [
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.CL',
          displayName: '计算与语言',
        ),
      ]);
      controller.selectChannel(3);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries, hasLength(2));

      controller.selectChannel(0);
      controller.selectChannel(3);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries, hasLength(2));

      controller.selectChannel(2);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries, hasLength(3));

      controller.selectChannel(0);
      controller.selectChannel(3);
      controller.selectChannel(2);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries, hasLength(3));
    });

    test('catalog refresh failures report once and surface the existing error',
        () async {
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: _FailingPaperCatalogRepository(),
      );
      addTearDown(feed.dispose);
      final events = <SparkDiagnosticEvent>[];

      await SparkDiagnostics.runWithSink(
        events.add,
        feed.initializeCatalog,
      );

      expect(feed.catalogError?.message, '论文目录暂时不可用，请稍后重试。');
      expect(
        events.map((event) => event.operation),
        [SparkDiagnosticOperation.paperFeedRefresh],
      );
    });

    test('catalog pagination failures report once and keep loaded papers',
        () async {
      final catalog = _FailingPaperCatalogRepository(
        firstPage: [_catalogPaper('kept-paper')],
      );
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
      );
      addTearDown(feed.dispose);
      await feed.initializeCatalog();
      final events = <SparkDiagnosticEvent>[];

      await SparkDiagnostics.runWithSink(
        events.add,
        feed.loadMoreCatalog,
      );

      expect(feed.papers.single.id, 'kept-paper');
      expect(feed.catalogError?.message, '无法加载更多论文，请稍后重试。');
      expect(
        events.map((event) => event.operation),
        [SparkDiagnosticOperation.paperFeedLoadMore],
      );
    });

    test('each channel keeps its own loaded papers', () async {
      final controller = PaperController(
        const ArxivSeedRepository(),
        catalogRepository: _CategoryPaperCatalogRepository(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.papers.take(2).map((paper) => paper.id),
          ['union-1', 'union-2']);

      await controller.saveUserChannels(const [
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.CL',
          displayName: '计算与语言',
        ),
      ]);
      controller.selectChannel(3);
      await controller.feed.flushCatalogOperations();
      expect(controller.papers.take(2).map((paper) => paper.id),
          ['cs.CL-1', 'cs.CL-2']);
      expect(
        controller.papers.map((paper) => paper.id),
        isNot(contains('union-1')),
      );

      controller.selectChannel(0);
      await controller.feed.flushCatalogOperations();
      expect(controller.papers.take(2).map((paper) => paper.id),
          ['union-1', 'union-2']);
    });

    test('each channel restores its own pagination cursor', () async {
      final catalog = _PerChannelOffsetCatalogRepository();
      final controller = PaperController(
        const ArxivSeedRepository(),
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.saveUserChannels(const [
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.CL',
          displayName: '计算与语言',
        ),
      ]);
      controller.selectChannel(3);
      await controller.feed.flushCatalogOperations();
      expect(controller.feed.catalogSource, PaperPageSource.cache);
      expect(controller.feed.catalogOffline, isTrue);
      expect(controller.feed.catalogStale, isTrue);
      expect(controller.feed.catalogError?.kind, PaperCatalogErrorKind.network);

      controller.selectChannel(0);
      expect(controller.feed.catalogSource, PaperPageSource.remote);
      expect(controller.feed.catalogOffline, isFalse);
      expect(controller.feed.catalogStale, isFalse);
      expect(controller.feed.catalogError, isNull);

      await controller.feed.loadMoreCatalog();

      expect(catalog.queries.last.offset, 20);
    });

    test('a pending pagination page cannot pollute a refreshed feed', () async {
      final catalog = _ConcurrentRefreshCatalogRepository();
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
      );
      addTearDown(feed.dispose);
      await feed.initializeCatalog();

      final pagination = feed.loadMoreCatalog();
      expect(feed.catalogLoadingMore, isTrue);
      final refresh = feed.refreshCatalog();
      expect(feed.catalogLoadingMore, isFalse);
      catalog.completeRefresh();
      await refresh;
      catalog.completePagination();
      await pagination;

      expect(feed.papers.map((paper) => paper.id), ['initial-page']);
      expect(feed.catalogHasMore, isFalse);
    });

    test('reloading preferences restores the current remote catalog', () async {
      final catalog = _ReloadPaperCatalogRepository();
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
      );
      addTearDown(feed.dispose);
      await feed.initializeCatalog();
      expect(feed.papers.single.id, 'reload-1');

      await feed.reloadPreferences();
      await feed.flushCatalogOperations();

      expect(catalog.loadCalls, 2);
      expect(feed.papers.single.id, 'reload-2');
    });

    test(
        'channel refresh keeps previously loaded papers available to following',
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
      await controller.saveUserChannels(const [
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.CL',
          displayName: '计算与语言',
        ),
      ]);
      controller.selectChannel(3);
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

    test('refresh appends unseen papers without discarding the buffer',
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

      expect(
        feed.papers.map((paper) => paper.id),
        orderedEquals(<String>[
          for (var index = 0; index < 20; index++) 'p$index',
          'new-paper',
        ]),
      );
      expect(feed.papers.first.title, 'Updated paper');
      expect(feed.papers, hasLength(21));
      expect(
        feed.papers.where((paper) => paper.id == 'p0'),
        hasLength(1),
      );
    });

    test('recommended refresh keeps ten papers and appends twenty new ones',
        () async {
      final catalog = _IncrementalRecommendationCatalogRepository();
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
        readPaperIdsProvider: () => const <String>{},
      );
      addTearDown(feed.dispose);

      await feed.initializeCatalog();
      expect(feed.papers, hasLength(10));

      await feed.refreshCatalog();

      expect(feed.papers, hasLength(30));
      expect(
        feed.papers.take(10).map((paper) => paper.id),
        orderedEquals(<String>[
          for (var index = 0; index < 10; index++) 'old-$index',
        ]),
      );
      expect(
        feed.papers.skip(10).map((paper) => paper.id),
        orderedEquals(<String>[
          for (var index = 0; index < 20; index++) 'new-$index',
        ]),
      );
      expect(
        catalog.queries.last.readPaperIds,
        orderedEquals(<String>[
          for (var index = 0; index < 10; index++) 'old-$index',
        ]),
      );
    });

    test('recommended refresh excludes the current channel buffer', () async {
      final catalog = _PagedPaperCatalogRepository(
        firstPage: List.generate(10, (index) => _catalogPaper('p$index')),
      );
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
        readPaperIdsProvider: () => const {'p0', 'p1'},
      );
      addTearDown(feed.dispose);

      await feed.initializeCatalog();
      await feed.refreshCatalog();

      expect(
        catalog.queries.last.readPaperIds,
        containsAll(<String>[
          for (var index = 0; index < 10; index++) 'p$index',
        ]),
      );
    });

    test('recommended requests include a bounded live read-id set', () async {
      final readIds = <String>{
        for (var index = 0; index < 205; index++) 'read-$index',
      };
      final catalog = _PagedPaperCatalogRepository(firstPage: const []);
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
        readPaperIdsProvider: () => readIds,
      );
      addTearDown(feed.dispose);

      await feed.initializeCatalog();

      final expectedReadIds = readIds.toList()..sort();
      expect(catalog.queries.single.channel, PaperFeedChannel.recommended);
      expect(catalog.queries.single.readPaperIds, hasLength(200));
      expect(
        catalog.queries.single.readPaperIds,
        orderedEquals(expectedReadIds.take(200)),
      );

      readIds
        ..clear()
        ..addAll({'read-new', 'read-second'});
      await feed.refreshCatalog();

      expect(
        catalog.queries.last.readPaperIds,
        orderedEquals(['read-new', 'read-second']),
      );
    });

    test('first successful catalog page replaces fallback papers', () async {
      final catalog = _PagedPaperCatalogRepository(
        firstPage: [_catalogPaper('remote-paper')],
      );
      final feed = PaperFeedController.fromPapers(
        [_catalogPaper('seed-paper')],
        catalogRepository: catalog,
      );
      addTearDown(feed.dispose);

      await feed.initializeCatalog();

      expect(feed.papers.map((paper) => paper.id), ['remote-paper']);
    });

    test('an empty refresh keeps papers from the previous batch', () async {
      final catalog = _PagedPaperCatalogRepository(
        firstPage: [_catalogPaper('old-paper')],
      );
      final feed = PaperFeedController.fromPapers(
        const [],
        catalogRepository: catalog,
      );
      addTearDown(feed.dispose);

      await feed.initializeCatalog();
      expect(feed.papers.map((paper) => paper.id), ['old-paper']);

      catalog.firstPage = const [];
      await feed.refreshCatalog();

      expect(feed.papers.map((paper) => paper.id), ['old-paper']);
      expect(feed.catalogHasMore, isFalse);
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

class _FailingPaperCatalogRepository implements PaperCatalogRepository {
  _FailingPaperCatalogRepository({this.firstPage = const []});

  final List<Paper> firstPage;
  var loadCalls = 0;

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    loadCalls++;
    if (loadCalls == 1 && firstPage.isNotEmpty) {
      return PaperPage(
        papers: firstPage,
        source: PaperPageSource.remote,
        nextOffset: 20,
      );
    }
    throw StateError('catalog unavailable');
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

class _CategoryPaperCatalogRepository implements PaperCatalogRepository {
  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    final category = query.category ?? '';
    final papers = category.contains('|')
        ? [_catalogPaper('union-1'), _catalogPaper('union-2')]
        : [
            _catalogPaper('$category-1'),
            _catalogPaper('$category-2'),
          ];
    return PaperPage(papers: papers, source: PaperPageSource.remote);
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

class _PerChannelOffsetCatalogRepository implements PaperCatalogRepository {
  final List<PaperFeedQuery> queries = [];

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    queries.add(query);
    if (query.offset > 0) {
      return PaperPage(papers: const [], source: PaperPageSource.remote);
    }
    final subjectChannel = query.category == 'cs.CL';
    return PaperPage(
      papers: [_catalogPaper(subjectChannel ? 'subject-page' : 'union-page')],
      source: subjectChannel ? PaperPageSource.cache : PaperPageSource.remote,
      nextOffset: subjectChannel ? 40 : 20,
      isOffline: subjectChannel,
      isStale: subjectChannel,
      error: subjectChannel
          ? const PaperCatalogError(
              kind: PaperCatalogErrorKind.network,
              message: 'offline',
            )
          : null,
    );
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

class _ConcurrentRefreshCatalogRepository implements PaperCatalogRepository {
  final _pagination = Completer<PaperPage>();
  final _refresh = Completer<PaperPage>();
  var _initialLoaded = false;

  void completeRefresh() {
    _refresh.complete(
      PaperPage(papers: const [], source: PaperPageSource.remote),
    );
  }

  void completePagination() {
    _pagination.complete(
      PaperPage(
        papers: [_catalogPaper('stale-pagination')],
        source: PaperPageSource.remote,
      ),
    );
  }

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) {
    if (!_initialLoaded) {
      _initialLoaded = true;
      return Future.value(
        PaperPage(
          papers: [_catalogPaper('initial-page')],
          source: PaperPageSource.remote,
          nextOffset: 20,
        ),
      );
    }
    if (query.offset > 0) return _pagination.future;
    return _refresh.future;
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

class _ReloadPaperCatalogRepository implements PaperCatalogRepository {
  int loadCalls = 0;

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    loadCalls++;
    return PaperPage(
      papers: [_catalogPaper('reload-$loadCalls')],
      source: PaperPageSource.remote,
    );
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

class _BlockingPaperPreferenceRepository implements PaperPreferenceRepository {
  final _load = Completer<PaperPreferences>();

  void complete(PaperPreferences preferences) => _load.complete(preferences);

  @override
  Future<PaperPreferences> load() => _load.future;

  @override
  Future<void> save(PaperPreferences preferences) async {}
}

class _FlakyPaperPreferenceRepository implements PaperPreferenceRepository {
  int saveCalls = 0;

  @override
  Future<PaperPreferences> load() async => PaperPreferences();

  @override
  Future<void> save(PaperPreferences preferences) async {
    saveCalls++;
    if (saveCalls == 1) throw StateError('disk unavailable');
  }
}

class _IncrementalRecommendationCatalogRepository
    implements PaperCatalogRepository {
  final List<PaperFeedQuery> queries = [];

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    queries.add(query);
    final prefix = queries.length == 1 ? 'old' : 'new';
    final count = queries.length == 1 ? 10 : 20;
    return PaperPage(
      papers: [
        for (var index = 0; index < count; index++)
          _catalogPaper('$prefix-$index')
      ],
      source: PaperPageSource.remote,
    );
  }

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

Paper _catalogPaper(
  String id, {
  String? title,
  DateTime? publishedAt,
}) =>
    Paper(
      id: id,
      title: title ?? 'Paper $id',
      authors: const ['Researcher'],
      affiliations: const ['Research Lab'],
      subjects: const ['cs.AI'],
      abstractText: 'Abstract for $id.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
      publishedAt: publishedAt ?? DateTime.utc(2026, 1, 1),
      source: 'arxiv',
    );
