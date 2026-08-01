import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../papers/domain/paper.dart';
import '../domain/paper_search_history_repository.dart';
import '../domain/paper_search_matcher.dart';

class PaperSearchController extends ChangeNotifier {
  PaperSearchController({
    required Iterable<Paper> papers,
    required PaperSearchHistoryRepository historyRepository,
    this.debounceDuration = const Duration(milliseconds: 250),
  })  : _papers = List.unmodifiable(papers),
        _historyRepository = historyRepository;

  static const maxHistoryLength = 12;

  final List<Paper> _papers;
  final PaperSearchHistoryRepository _historyRepository;
  final Duration debounceDuration;

  Timer? _debounce;
  String _query = '';
  List<Paper> _results = const [];
  List<String> _history = const [];
  bool _loadingHistory = true;
  String? _historyError;

  String get query => _query;
  List<Paper> get results => _results;
  List<String> get history => _history;
  bool get loadingHistory => _loadingHistory;
  String? get historyError => _historyError;

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
      _results = const [];
      notifyListeners();
      return;
    }
    _debounce = Timer(debounceDuration, _search);
    notifyListeners();
  }

  Future<void> submitQuery(String value) async {
    _query = value.trim();
    _debounce?.cancel();
    _search();
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

  void _search() {
    _results = PaperSearchMatcher.search(_papers, _query);
    notifyListeners();
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
    super.dispose();
  }
}
