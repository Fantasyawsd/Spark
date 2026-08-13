import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_controller.dart';
import 'package:spark/src/features/papers/application/paper_feed_controller.dart';
import 'package:spark/src/features/papers/application/paper_interaction_controller.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';
import 'package:spark/src/features/papers/domain/paper_channel.dart';
import 'package:spark/src/features/papers/domain/paper_interaction_repository.dart';

void main() {
  test('feed reacts directly to the interaction follow source', () {
    final interactions = PaperInteractionController();
    final feed = PaperFeedController(
      const ArxivSeedRepository(),
      followedPaperIdsListenable: interactions.followedPaperIdsListenable,
    );
    addTearDown(feed.dispose);
    addTearDown(interactions.dispose);

    final followed = feed.allPapers.first;
    feed.selectChannel(FixedPaperChannel.following.index);
    expect(feed.papers, isEmpty);

    interactions.toggleFollowAuthor(followed);
    expect(
      feed.papers,
      everyElement(
        predicate<Paper>(
          (paper) => paper.authorKey == followed.authorKey,
        ),
      ),
    );
    expect(feed.papers, isNotEmpty);

    interactions.toggleFollowAuthor(followed);
    expect(feed.papers, isEmpty);
  });

  test('interaction exposes immutable follow snapshots', () {
    final interactions = PaperInteractionController(
      initiallyFollowed: const ['author:ada'],
    );
    addTearDown(interactions.dispose);

    expect(
      () => interactions.followedPaperIds.add('author:grace'),
      throwsUnsupportedError,
    );
    expect(
      () => interactions.followedPaperIdsListenable.value.add('author:grace'),
      throwsUnsupportedError,
    );
  });

  test('follow changes leave other channels loaded until following is opened',
      () async {
    final interactions = PaperInteractionController();
    final catalog = _RecordingCatalog();
    final feed = PaperFeedController(
      const ArxivSeedRepository(),
      catalogRepository: catalog,
      followedPaperIdsListenable: interactions.followedPaperIdsListenable,
    );
    addTearDown(feed.dispose);
    addTearDown(interactions.dispose);

    await feed.initializeCatalog();
    expect(catalog.queries, hasLength(1));
    final followed = feed.allPapers.first;

    interactions.toggleFollowAuthor(followed);
    await feed.flushCatalogOperations();
    expect(catalog.queries, hasLength(1));

    feed.selectChannel(FixedPaperChannel.following.index);
    await feed.flushCatalogOperations();
    expect(catalog.queries, hasLength(2));
    expect(catalog.queries.last.channel, PaperFeedChannel.following);
    expect(catalog.queries.last.followingAuthors, [
      followed.firstAuthor.toLowerCase(),
    ]);
  });

  test('legacy paper ids still resolve authors from the single source',
      () async {
    final papers = const ArxivSeedRepository().getAll();
    final paper = papers.first;
    final second = papers.firstWhere(
      (candidate) => candidate.authorKey != paper.authorKey,
    );
    final interactions = PaperInteractionController(
      initiallyFollowed: [paper.id],
    );
    final catalog = _RecordingCatalog();
    final feed = PaperFeedController(
      const ArxivSeedRepository(),
      catalogRepository: catalog,
      followedPaperIdsListenable: interactions.followedPaperIdsListenable,
    );
    addTearDown(feed.dispose);
    addTearDown(interactions.dispose);

    feed.selectChannel(FixedPaperChannel.following.index);
    await feed.flushCatalogOperations();

    expect(catalog.queries.single.followingAuthors, [
      paper.firstAuthor.toLowerCase(),
    ]);

    interactions.toggleFollowAuthor(second);
    await feed.flushCatalogOperations();
    expect(catalog.queries, hasLength(2));
    expect(
        catalog.queries.last.followingAuthors,
        [
          paper.firstAuthor.toLowerCase(),
          second.firstAuthor.toLowerCase(),
        ]..sort());
  });

  test('initialization, reload and failed writes publish one follow source',
      () async {
    final papers = const ArxivSeedRepository().getAll();
    final first = papers.first;
    final second = papers.firstWhere(
      (paper) => paper.authorKey != first.authorKey,
    );
    final repository = _ControlledInteractionRepository(
      PaperInteractionSnapshot(followedPaperIds: [first.authorKey]),
    );
    final controller = PaperController(
      const ArxivSeedRepository(),
      interactionRepository: repository,
    );
    addTearDown(controller.dispose);

    controller.selectChannel(FixedPaperChannel.following.index);
    expect(controller.papers, isEmpty);
    await controller.initialize();
    expect(
      controller.papers.every((paper) => paper.authorKey == first.authorKey),
      isTrue,
    );
    expect(controller.papers, isNotEmpty);

    repository.snapshot = PaperInteractionSnapshot(
      followedPaperIds: [second.authorKey],
    );
    await controller.interactions.reload();
    expect(
      controller.papers.every((paper) => paper.authorKey == second.authorKey),
      isTrue,
    );
    expect(controller.papers, isNotEmpty);

    repository.failNextSave = true;
    controller.interactions.toggleFollowAuthor(first);
    expect(controller.papers.any((paper) => paper.authorKey == first.authorKey),
        isTrue);
    await controller.interactions.flushPendingWrites();
    expect(
      controller.papers.every((paper) => paper.authorKey == second.authorKey),
      isTrue,
    );
  });

  test('feed removes its listener when disposed', () {
    final followedIds = _TrackingFollowedIds();
    final feed = PaperFeedController(
      const ArxivSeedRepository(),
      followedPaperIdsListenable: followedIds,
    );

    expect(followedIds.addCalls, 1);
    feed.dispose();
    expect(followedIds.removeCalls, 1);
    followedIds.dispose();
  });
}

class _TrackingFollowedIds extends ValueNotifier<Set<String>> {
  _TrackingFollowedIds() : super(const {});

  int addCalls = 0;
  int removeCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    addCalls++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeCalls++;
    super.removeListener(listener);
  }
}

class _ControlledInteractionRepository implements PaperInteractionRepository {
  _ControlledInteractionRepository(this.snapshot);

  PaperInteractionSnapshot snapshot;
  bool failNextSave = false;

  @override
  Future<PaperInteractionSnapshot> load() async => snapshot;

  @override
  Future<void> save(PaperInteractionSnapshot snapshot) async {
    if (failNextSave) {
      failNextSave = false;
      throw const PaperInteractionPersistenceException('保存失败');
    }
    this.snapshot = snapshot;
  }
}

class _RecordingCatalog implements PaperCatalogRepository {
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
