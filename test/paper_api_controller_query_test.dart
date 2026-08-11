import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_controller.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';
import 'package:spark/src/features/papers/domain/paper_channel.dart';

void main() {
  test(
    'fixed and user channels carry their server-side channel semantics',
    () async {
      final catalog = _RecordingCatalog();
      final controller = PaperController(
        const ArxivSeedRepository(),
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(catalog.queries.single.channel, PaperFeedChannel.recommended);

      controller.selectChannel(FixedPaperChannel.latest.index);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries.last.channel, PaperFeedChannel.latest);

      await controller.saveUserChannels(const [
        UserPaperChannel(
          kind: PaperChannelKind.subject,
          id: 'cs.AI',
          displayName: '人工智能',
        ),
        UserPaperChannel(
          kind: PaperChannelKind.conference,
          id: 'ICML',
          displayName: 'ICML',
        ),
      ]);
      controller.selectChannel(3);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries.last.channel, PaperFeedChannel.subject);
      expect(catalog.queries.last.category, 'cs.AI');

      controller.selectChannel(4);
      await controller.feed.flushCatalogOperations();
      expect(catalog.queries.last.channel, PaperFeedChannel.conference);
      expect(catalog.queries.last.category, 'ICML');
    },
  );

  test('following channel sends followed author identities', () async {
    final catalog = _RecordingCatalog();
    final controller = PaperController(
      const ArxivSeedRepository(),
      catalogRepository: catalog,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final paper = controller.feed.allPapers.first;
    controller.interactions.toggleFollowAuthor(paper);
    controller.selectChannel(FixedPaperChannel.following.index);
    await controller.feed.flushCatalogOperations();

    expect(catalog.queries.last.channel, PaperFeedChannel.following);
    expect(catalog.queries.last.followingAuthors, [
      paper.firstAuthor.toLowerCase(),
    ]);
  });

  test('opaque API cursors are passed to the next catalog query', () async {
    final catalog = _RecordingCatalog(withCursor: true);
    final controller = PaperController(
      const ArxivSeedRepository(),
      catalogRepository: catalog,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.feed.loadMoreCatalog();

    expect(catalog.queries, hasLength(2));
    expect(catalog.queries.last.cursor, 'opaque-page-2');
    expect(catalog.queries.last.offset, 0);
  });
}

final class _RecordingCatalog implements PaperCatalogRepository {
  _RecordingCatalog({this.withCursor = false});

  final bool withCursor;
  final List<PaperFeedQuery> queries = [];

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    queries.add(query);
    return PaperPage(
      papers: const [],
      source: PaperPageSource.remote,
      nextCursor: withCursor && queries.length == 1 ? 'opaque-page-2' : null,
    );
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}
