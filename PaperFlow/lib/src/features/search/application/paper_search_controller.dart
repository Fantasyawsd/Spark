import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../papers/domain/paper.dart';
import '../../papers/domain/paper_catalog.dart';
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
  String _query = '';
  List<Paper> _results = const [];
  List<String> _history = const [];
  bool _loadingHistory = true;
  String? _historyError;
  bool _loadingResults = false;
  bool _loadingMoreResults = false;
  PaperCatalogError? _resultsError;
  int? _nextOffset;
  int _searchGeneration = 0;

  String get query => _query;
  List<Paper> get results => _results;
  List<String> get history => _history;
  bool get loadingHistory => _loadingHistory;
  String? get historyError => _historyError;
  bool get loadingResults => _loadingResults;
  bool get loadingMoreResults => _loadingMoreResults;
  PaperCatalogError? get resultsError => _resultsError;
  bool get hasMoreResults => _nextOffset != null;

  Future<void> initialize() async {
    try {
      _history = await _historyRepository.load();
      _historyError = null;
    } on PaperSearchHistoryException catch (error) {
      _history = const [];
      _historyError = error.message;
    } finally {
      _loadingHistory = false;
      notifyListeners();
    }
  }

  void updateQuery(String value) {
    _query = value;
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _searchGeneration++;
      _results = const [];
      _nextOffset = null;
      _resultsError = null;
      _loadingResults = false;
      notifyListeners();
      return;
    }
    _debounce = Timer(debounceDuration, _search);
    notifyListeners();
  }

  Future<void> submitQuery(String value) async {
    _query = value.trim();
    _debounce?.cancel();
    await _search();
    await rememberCurrentQuery();
  }

  Future<void> rememberCurrentQuery() async {
    final value = _query.trim();
    if (value.isEmpty) return;
    _history = [
      value,
      ..._history.where((item) => item.toLowerCase() != value.toLowerCase()),
    ].take(maxHistoryLength).toList(growable: false);
    await _saveHistory();
  }

  Future<void> removeHistory(String value) async {
    _history = _history.where((item) => item != value).toList(growable: false);
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    _history = const [];
    await _saveHistory();
  }

  Future<void> _search() async {
    final generation = ++_searchGeneration;
    final repository = catalogRepository;
    if (repository == null) {
      _results = PaperSearchMatcher.search(_papers, _query);
      notifyListeners();
      return;
    }
    final term = _query.trim();
    if (term.isEmpty) {
      _results = const [];
      _nextOffset = null;
      _resultsError = null;
      _loadingResults = false;
      notifyListeners();
      return;
    }
    _loadingResults = true;
    _resultsError = null;
    notifyListeners();
    try {
      final page = await repository.search(
        PaperSearchQuery(term: term, limit: 20, forceRefresh: true),
      );
      if (generation != _searchGeneration) return;
      _results = page.papers;
      _nextOffset = page.nextOffset;
      _resultsError = page.error;
    } on Object catch (_) {
      if (generation != _searchGeneration) return;
      _resultsError = const PaperCatalogError(
        kind: PaperCatalogErrorKind.unavailable,
        message: '搜索服务暂时不可用。',
      );
      _results = PaperSearchMatcher.search(_papers, _query);
      _nextOffset = null;
    } finally {
      if (generation == _searchGeneration) {
        _loadingResults = false;
        notifyListeners();
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
        _loadingMoreResults) {
      return;
    }
    _loadingMoreResults = true;
    notifyListeners();
    try {
      final page = await repository.search(
        PaperSearchQuery(term: term, offset: nextOffset, limit: 20),
      );
      if (term != _query.trim()) return;
      final existingIds = _results.map((paper) => paper.id).toSet();
      _results = [
        ..._results,
        ...page.papers.where((paper) => existingIds.add(paper.id)),
      ];
      _nextOffset = page.nextOffset;
      _resultsError = page.error;
    } on Object catch (_) {
      _resultsError = const PaperCatalogError(
        kind: PaperCatalogErrorKind.unavailable,
        message: '无法加载更多搜索结果。',
      );
    } finally {
      _loadingMoreResults = false;
      notifyListeners();
    }
  }

  Future<void> _saveHistory() async {
    try {
      await _historyRepository.save(_history);
      _historyError = null;
    } on PaperSearchHistoryException catch (error) {
      _historyError = error.message;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchGeneration++;
    super.dispose();
  }
}
