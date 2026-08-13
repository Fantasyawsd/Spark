import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/paper_catalog.dart';

typedef PaperCatalogPageHandler = void Function(
  PaperPage page, {
  required String channelKey,
  required bool append,
  required int queryRevision,
});

typedef PaperCatalogErrorHandler = void Function(
  Object error,
  StackTrace stackTrace, {
  required String channelKey,
  required bool append,
  required int queryRevision,
});

class PaperFeedCatalogOperations {
  PaperFeedCatalogOperations({
    required PaperCatalogRepository? repository,
    required bool Function() isDisposed,
    required VoidCallback notify,
    required VoidCallback onStaleRefresh,
    required PaperCatalogPageHandler onPage,
    required PaperCatalogErrorHandler onError,
  })  : _repository = repository,
        _isDisposed = isDisposed,
        _notify = notify,
        _onStaleRefresh = onStaleRefresh,
        _onPage = onPage,
        _onError = onError;

  final PaperCatalogRepository? _repository;
  final bool Function() _isDisposed;
  final VoidCallback _notify;
  final VoidCallback _onStaleRefresh;
  final PaperCatalogPageHandler _onPage;
  final PaperCatalogErrorHandler _onError;
  final Set<Future<void>> _operations = {};
  int _queryRevision = 0;
  bool _loading = false;
  bool _loadingMore = false;

  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  int get currentRevision => _queryRevision;

  int advanceQueryRevision() {
    _loadingMore = false;
    return ++_queryRevision;
  }

  Future<void> refresh({
    required String channelKey,
    required PaperFeedQuery query,
    required int queryRevision,
  }) {
    if (_repository == null || _isDisposed() || _loading) {
      return Future.value();
    }
    return _track(
      _run(
        channelKey: channelKey,
        query: query,
        queryRevision: queryRevision,
        append: false,
      ),
    );
  }

  Future<void> loadMore({
    required String channelKey,
    required PaperFeedQuery query,
    required int queryRevision,
  }) {
    if (_repository == null || _isDisposed() || _loading || _loadingMore) {
      return Future.value();
    }
    return _track(
      _run(
        channelKey: channelKey,
        query: query,
        queryRevision: queryRevision,
        append: true,
      ),
    );
  }

  Future<void> flush() async {
    while (_operations.isNotEmpty) {
      await Future.wait(_operations.toList(growable: false));
    }
  }

  Future<void> _run({
    required String channelKey,
    required PaperFeedQuery query,
    required int queryRevision,
    required bool append,
  }) async {
    if (append) {
      _loadingMore = true;
    } else {
      _loading = true;
    }
    _notify();
    try {
      final page = await _repository!.loadFeed(query);
      if (!_isDisposed() && queryRevision == _queryRevision) {
        _onPage(
          page,
          channelKey: channelKey,
          append: append,
          queryRevision: queryRevision,
        );
      }
    } on Object catch (error, stackTrace) {
      _onError(
        error,
        stackTrace,
        channelKey: channelKey,
        append: append,
        queryRevision: queryRevision,
      );
    } finally {
      if (append) {
        _loadingMore = false;
      } else {
        _loading = false;
      }
      _notify();
      if (!append && !_isDisposed() && queryRevision != _queryRevision) {
        _onStaleRefresh();
      }
    }
  }

  Future<void> _track(Future<void> operation) {
    late final Future<void> tracked;
    tracked = operation.whenComplete(() => _operations.remove(tracked));
    _operations.add(tracked);
    return tracked;
  }
}
