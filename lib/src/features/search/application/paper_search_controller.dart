import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../papers/papers.dart';
import '../domain/arxiv_paper_id.dart';
import '../domain/paper_search_history_repository.dart';
import '../domain/paper_search_matcher.dart';

class PaperSearchController extends ChangeNotifier {
  PaperSearchController({
    required Iterable<Paper> papers,
    required PaperSearchHistoryRepository historyRepository,
    this.catalogRepository,
    this.debounceDuration = const Duration(milliseconds: 250),
  })  : _papers = List.unmodifiable(papers),
        _historyRepository = historyRepository;

  static const maxHistoryLength = 12;

  final List<Paper> _papers;
  final PaperSearchHistoryRepository _historyRepository;
  final PaperCatalogRepository? catalogRepository;
  final Duration debounceDuration;

  Timer? _debounce;
  Future<void>? _historyLoadOperation;
  Future<void> _historyWriteQueue = Future.value();
  final List<_HistoryMutation> _pendingHistoryMutations = [];
  String _query = '';
  List<Paper> _results = const [];
  List<String> _history = const [];
  bool _loadingHistory = true;
  bool _historyLoadInProgress = false;
  String? _historyError;
  bool _loadingResults = false;
  bool _loadingMoreResults = false;
  PaperCatalogError? _resultsError;
  int? _nextOffset;
  int _searchGeneration = 0;
  int _historyWriteRevision = 0;
  bool _disposed = false;

  String get query => _query;
  List<Paper> get results => _results;
  List<String> get history => _history;
  bool get loadingHistory => _loadingHistory;
  String? get historyError => _historyError;
  bool get loadingResults => _loadingResults;
  bool get loadingMoreResults => _loadingMoreResults;
  PaperCatalogError? get resultsError => _resultsError;
  bool get hasMoreResults => _nextOffset != null;

  Future<void> initialize() {
    if (_disposed) return Future.value();
    final activeOperation = _historyLoadOperation;
    if (activeOperation != null) return activeOperation;
    _historyLoadInProgress = true;
    late final Future<void> operation;
    operation = _initializeHistory().whenComplete(() {
      if (identical(_historyLoadOperation, operation)) {
        _historyLoadOperation = null;
      }
    });
    _historyLoadOperation = operation;
    return operation;
  }

  Future<void> _initializeHistory() async {
    try {
      final history = await _historyRepository.load();
      if (_disposed) return;
      var restored = List<String>.of(history);
      for (final mutation in _pendingHistoryMutations) {
        restored = _applyHistoryMutation(restored, mutation);
      }
      _history = restored;
      _pendingHistoryMutations.clear();
      _historyError = null;
    } on Object catch (error) {
      if (_disposed) return;
      _pendingHistoryMutations.clear();
      _historyError = _historyErrorMessage(error, reading: true);
    } finally {
      if (!_disposed) {
        _historyLoadInProgress = false;
        _loadingHistory = false;
        _notify();
      }
    }
  }

  void updateQuery(String value) {
    if (_disposed) return;
    _query = value;
    _debounce?.cancel();
    _searchGeneration++;
    _loadingResults = false;
    _loadingMoreResults = false;
    _nextOffset = null;
    _resultsError = null;
    if (value.trim().isEmpty) {
      _results = const [];
      _notify();
      return;
    }
    _debounce = Timer(debounceDuration, _search);
    _notify();
  }

  Future<void> submitQuery(String value) async {
    if (_disposed) return;
    final submittedQuery = value.trim();
    _query = submittedQuery;
    _debounce?.cancel();
    await _search();
    if (_disposed || _query != submittedQuery) return;
    await rememberCurrentQuery();
  }

  Future<void> rememberCurrentQuery() async {
    if (_disposed) return;
    final value = _query.trim();
    if (value.isEmpty) return;
    _applyAndRecordHistoryMutation(_HistoryMutation.remember(value));
    await _saveHistory();
  }

  Future<void> removeHistory(String value) async {
    if (_disposed) return;
    _applyAndRecordHistoryMutation(_HistoryMutation.remove(value));
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    if (_disposed) return;
    _applyAndRecordHistoryMutation(const _HistoryMutation.clear());
    await _saveHistory();
  }

  Future<void> _search() async {
    if (_disposed) return;
    final generation = ++_searchGeneration;
    _loadingMoreResults = false;
    _nextOffset = null;
    _resultsError = null;
    final repository = catalogRepository;
    if (repository == null) {
      _loadingResults = false;
      _results = PaperSearchMatcher.search(_papers, _query);
      _notify();
      return;
    }
    final term = _query.trim();
    if (term.isEmpty) {
      _results = const [];
      _nextOffset = null;
      _resultsError = null;
      _loadingResults = false;
      _notify();
      return;
    }
    final arxivId = extractArxivId(term);
    if (arxivId != null) {
      _loadingResults = true;
      _resultsError = null;
      _notify();
      try {
        final paper = await repository.findById(arxivId);
        if (!_isCurrent(generation)) return;
        _results = paper == null ? const [] : [paper];
        _nextOffset = null;
      } on Object catch (_) {
        if (!_isCurrent(generation)) return;
        _results = const [];
        _nextOffset = null;
        _resultsError = const PaperCatalogError(
          kind: PaperCatalogErrorKind.unavailable,
          message: '按 arXiv ID 获取论文失败。',
        );
      } finally {
        if (_isCurrent(generation)) {
          _loadingResults = false;
          _notify();
        }
      }
      return;
    }

    _loadingResults = true;
    _resultsError = null;
    _notify();
    try {
      final page = await repository.search(
        PaperSearchQuery(term: term, limit: 20, forceRefresh: true),
      );
      if (!_isCurrent(generation)) return;
      _results = page.papers;
      _nextOffset = page.nextOffset;
      _resultsError = page.error;
    } on Object catch (_) {
      if (!_isCurrent(generation)) return;
      _resultsError = const PaperCatalogError(
        kind: PaperCatalogErrorKind.unavailable,
        message: '搜索服务暂时不可用。',
      );
      _results = PaperSearchMatcher.search(_papers, _query);
      _nextOffset = null;
    } finally {
      if (_isCurrent(generation)) {
        _loadingResults = false;
        _notify();
      }
    }
  }

  Future<void> loadMoreResults() async {
    final repository = catalogRepository;
    final nextOffset = _nextOffset;
    final term = _query.trim();
    if (repository == null ||
        nextOffset == null ||
        term.isEmpty ||
        _loadingResults ||
        _loadingMoreResults ||
        _disposed) {
      return;
    }
    final generation = _searchGeneration;
    _loadingMoreResults = true;
    _notify();
    try {
      final page = await repository.search(
        PaperSearchQuery(term: term, offset: nextOffset, limit: 20),
      );
      if (!_isCurrent(generation) || term != _query.trim()) return;
      final existingIds = _results.map((paper) => paper.id).toSet();
      _results = [
        ..._results,
        ...page.papers.where((paper) => existingIds.add(paper.id)),
      ];
      _nextOffset = page.nextOffset;
      _resultsError = page.error;
    } on Object catch (_) {
      if (_isCurrent(generation)) {
        _resultsError = const PaperCatalogError(
          kind: PaperCatalogErrorKind.unavailable,
          message: '无法加载更多搜索结果。',
        );
      }
    } finally {
      if (_isCurrent(generation)) {
        _loadingMoreResults = false;
        _notify();
      }
    }
  }

  Future<void> _saveHistory() async {
    final activeLoad = _historyLoadOperation;
    if (activeLoad != null) await activeLoad;
    if (_disposed) return;
    final snapshot = List<String>.unmodifiable(_history);
    final revision = ++_historyWriteRevision;
    _historyWriteQueue = _historyWriteQueue.then(
      (_) => _persistHistory(snapshot, revision),
    );
    await _historyWriteQueue;
  }

  Future<void> _persistHistory(List<String> history, int revision) async {
    if (_disposed) return;
    String? errorMessage;
    try {
      await _historyRepository.save(history);
    } on Object catch (error) {
      errorMessage = _historyErrorMessage(error, reading: false);
    }
    if (_disposed || revision != _historyWriteRevision) return;
    _historyError = errorMessage;
    _notify();
  }

  void _applyAndRecordHistoryMutation(_HistoryMutation mutation) {
    _history = _applyHistoryMutation(_history, mutation);
    if (_historyLoadInProgress) {
      _pendingHistoryMutations.add(mutation);
    }
    _notify();
  }

  List<String> _applyHistoryMutation(
    List<String> history,
    _HistoryMutation mutation,
  ) {
    return switch (mutation.kind) {
      _HistoryMutationKind.remember => [
          mutation.value!,
          ...history.where(
            (item) => item.toLowerCase() != mutation.value!.toLowerCase(),
          ),
        ].take(maxHistoryLength).toList(growable: false),
      _HistoryMutationKind.remove =>
        history.where((item) => item != mutation.value).toList(growable: false),
      _HistoryMutationKind.clear => const [],
    };
  }

  String _historyErrorMessage(Object error, {required bool reading}) {
    if (error is PaperSearchHistoryException) return error.message;
    return reading ? '无法读取搜索历史。' : '无法保存搜索历史。';
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _searchGeneration;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _searchGeneration++;
    super.dispose();
  }
}

enum _HistoryMutationKind { remember, remove, clear }

class _HistoryMutation {
  const _HistoryMutation._(this.kind, [this.value]);

  const _HistoryMutation.remember(String value)
      : this._(_HistoryMutationKind.remember, value);

  const _HistoryMutation.remove(String value)
      : this._(_HistoryMutationKind.remove, value);

  const _HistoryMutation.clear() : this._(_HistoryMutationKind.clear);

  final _HistoryMutationKind kind;
  final String? value;
}
