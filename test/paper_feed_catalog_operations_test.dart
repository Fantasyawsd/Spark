import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_feed_catalog_operations.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';

void main() {
  test('tracks loading and flushes an in-flight refresh', () async {
    final repository = _BlockingCatalogRepository();
    final pages = <PaperPage>[];
    final operations = PaperFeedCatalogOperations(
      repository: repository,
      isDisposed: () => false,
      notify: () {},
      onStaleRefresh: () {},
      onPage: (
        page, {
        required channelKey,
        required append,
        required queryRevision,
      }) =>
          pages.add(page),
      onError: (
        _,
        __, {
        required channelKey,
        required append,
        required queryRevision,
      }) {},
    );

    final request = operations.refresh(
      channelKey: 'fixed:latest',
      query: const PaperFeedQuery(channel: PaperFeedChannel.latest),
      queryRevision: operations.advanceQueryRevision(),
    );
    expect(operations.loading, isTrue);
    var flushed = false;
    final barrier = operations.flush().then((_) => flushed = true);
    await Future<void>.delayed(Duration.zero);
    expect(flushed, isFalse);

    repository.complete();
    await Future.wait([request, barrier]);

    expect(flushed, isTrue);
    expect(operations.loading, isFalse);
    expect(pages, hasLength(1));
  });

  test('a newer revision prevents an older page from being applied', () async {
    final repository = _SequencedCatalogRepository();
    var applied = 0;
    var staleRefreshes = 0;
    final operations = PaperFeedCatalogOperations(
      repository: repository,
      isDisposed: () => false,
      notify: () {},
      onStaleRefresh: () => staleRefreshes++,
      onPage: (
        _, {
        required channelKey,
        required append,
        required queryRevision,
      }) =>
          applied++,
      onError: (
        _,
        __, {
        required channelKey,
        required append,
        required queryRevision,
      }) {},
    );

    final old = operations.refresh(
      channelKey: 'fixed:latest',
      query: const PaperFeedQuery(channel: PaperFeedChannel.latest),
      queryRevision: operations.advanceQueryRevision(),
    );
    operations.advanceQueryRevision();
    repository.completeFirst();
    await old;

    expect(applied, 0);
    expect(staleRefreshes, 1);
  });
}

class _BlockingCatalogRepository implements PaperCatalogRepository {
  final Completer<void> _completion = Completer<void>();

  void complete() => _completion.complete();

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    await _completion.future;
    return PaperPage(papers: const [], source: PaperPageSource.remote);
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}

class _SequencedCatalogRepository implements PaperCatalogRepository {
  final Completer<void> _first = Completer<void>();

  void completeFirst() => _first.complete();

  @override
  Future<Paper?> findById(String paperId) async => null;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    await _first.future;
    return PaperPage(papers: const [], source: PaperPageSource.remote);
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async =>
      PaperPage(papers: const [], source: PaperPageSource.remote);
}
