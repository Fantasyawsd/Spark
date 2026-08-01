import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/paper.dart';
import '../domain/paper_catalog.dart';
import '../domain/paper_feed_filter.dart';
import '../domain/paper_preference_repository.dart';
import '../domain/paper_repository.dart';

class PaperFeedController extends ChangeNotifier {
  PaperFeedController(
    PaperRepository repository, {
    PaperPreferenceRepository? preferenceRepository,
    PaperCatalogRepository? catalogRepository,
  }) : this.fromPapers(
          repository.getAll(),
          preferenceRepository: preferenceRepository,
          catalogRepository: catalogRepository,
        );

  PaperFeedController.fromPapers(
    Iterable<Paper> papers, {
    PaperPreferenceRepository? preferenceRepository,
    PaperCatalogRepository? catalogRepository,
  })  : _allPapers = List.unmodifiable(papers),
        _preferenceRepository = preferenceRepository,
        _catalogRepository = catalogRepository {
    _refreshVisiblePapers();
  }

  static const primaryCategories = ['推荐', '关注', '最新'];
  static const defaultTopics = [
    '全部',
    'LLM',
    'NLP',
    'CV',
    'Agent',
    '多模态',
    'Systems',
    'Mathematics',
    'Biology',
  ];

  List<Paper> _allPapers;
  late List<Paper> _visiblePapers;
  Set<String> _followedPaperIds = {};
  final PaperPreferenceRepository? _preferenceRepository;
  final PaperCatalogRepository? _catalogRepository;
  Future<void> _preferenceWriteQueue = Future.value();
  String? _preferenceError;
  final Map<String, int> _positions = {};
  List<String> _extraCategories = [];
  int _primaryCategoryIndex = 0;
  int _topicIndex = 0;
  int _currentPaperIndex = 0;
  bool _gridMode = false;
  bool _catalogLoading = false;
  bool _catalogLoadingMore = false;
  bool _catalogOffline = false;
  bool _catalogStale = false;
  int? _catalogNextOffset;
  PaperCatalogError? _catalogError;
  bool _disposed = false;

  List<Paper> get papers => _visiblePapers;
  List<Paper> get allPapers => _allPapers;
  List<String> get extraCategories => List.unmodifiable(_extraCategories);
  List<String> get topics => [...defaultTopics, ..._extraCategories];
  int get primaryCategoryIndex => _primaryCategoryIndex;
  int get topicIndex => _topicIndex;
  int get categoryIndex => _topicIndex;
  int get currentPaperIndex => _currentPaperIndex;
  bool get gridMode => _gridMode;
  String? get preferenceError => _preferenceError;
  bool get catalogLoading => _catalogLoading;
  bool get catalogLoadingMore => _catalogLoadingMore;
  bool get catalogOffline => _catalogOffline;
  bool get catalogStale => _catalogStale;
  bool get catalogHasMore => _catalogNextOffset != null;
  PaperCatalogError? get catalogError => _catalogError;

  Future<void> initializeCatalog() => refreshCatalog(forceRefresh: false);

  Future<void> refreshCatalog({bool forceRefresh = true}) async {
    final repository = _catalogRepository;
    if (repository == null || _catalogLoading) return;
    _catalogLoading = true;
    notifyListeners();
    try {
      final page = await repository.loadFeed(
        PaperFeedQuery(limit: 20, forceRefresh: forceRefresh),
      );
      _applyCatalogPage(page, append: false);
    } on Object catch (_) {
      _catalogError = const PaperCatalogError(
        kind: PaperCatalogErrorKind.unavailable,
        message: '论文目录暂时不可用，请稍后重试。',
      );
    } finally {
      _catalogLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> loadMoreCatalog() async {
    final repository = _catalogRepository;
    final nextOffset = _catalogNextOffset;
    if (repository == null ||
        nextOffset == null ||
        _catalogLoading ||
        _catalogLoadingMore) {
      return;
    }
    _catalogLoadingMore = true;
    notifyListeners();
    try {
      final page = await repository.loadFeed(
        PaperFeedQuery(offset: nextOffset, limit: 20),
      );
      _applyCatalogPage(page, append: true);
    } on Object catch (_) {
      _catalogError = const PaperCatalogError(
        kind: PaperCatalogErrorKind.unavailable,
        message: '无法加载更多论文，请稍后重试。',
      );
    } finally {
      _catalogLoadingMore = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> initializePreferences() async {
    final repository = _preferenceRepository;
    if (repository == null) return;
    try {
      final preferences = await repository.load();
      _extraCategories = List.of(preferences.extraTopics);
      _positions
        ..clear()
        ..addAll(preferences.positions);
      _primaryCategoryIndex = preferences.primaryCategoryIndex.clamp(
        0,
        primaryCategories.length - 1,
      );
      _topicIndex = preferences.topicIndex.clamp(0, topics.length - 1);
      _preferenceError = null;
      _restorePosition();
    } on PaperPreferencePersistenceException catch (error) {
      _preferenceError = error.message;
    }
    notifyListeners();
  }

  void toggleGridMode() {
    _gridMode = !_gridMode;
    notifyListeners();
  }

  void openPaper(int index) {
    if (index < 0 || index >= _visiblePapers.length) return;
    _currentPaperIndex = index;
    _gridMode = false;
    notifyListeners();
    _queuePreferencePersistence();
  }

  void openPaperById(String paperId) {
    final exists = _allPapers.any((paper) => paper.id == paperId);
    if (!exists) return;
    _rememberPosition();
    _primaryCategoryIndex = PaperFeedMode.recommended.index;
    _topicIndex = 0;
    _refreshVisiblePapers();
    _currentPaperIndex =
        _visiblePapers.indexWhere((paper) => paper.id == paperId);
    _positions[_filterKey] = _currentPaperIndex;
    _gridMode = false;
    notifyListeners();
    _queuePreferencePersistence();
  }

  void selectPaper(int index) {
    if (index == _currentPaperIndex ||
        index < 0 ||
        index >= _visiblePapers.length) {
      return;
    }
    _currentPaperIndex = index;
    _positions[_filterKey] = index;
    notifyListeners();
    _queuePreferencePersistence();
    if (index >= _visiblePapers.length - 3) {
      unawaited(loadMoreCatalog());
    }
  }

  void selectPrimaryCategory(int index) {
    if (index == _primaryCategoryIndex ||
        index < 0 ||
        index >= primaryCategories.length) {
      return;
    }
    _rememberPosition();
    _primaryCategoryIndex = index;
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
  }

  void selectTopic(int index) {
    if (index == _topicIndex || index < 0 || index >= topics.length) {
      return;
    }
    _rememberPosition();
    _topicIndex = index;
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
  }

  void selectTopicByName(String topic) {
    final normalized = topic.trim();
    if (normalized.isEmpty) return;
    final existingIndex = topics.indexOf(normalized);
    if (existingIndex >= 0) {
      selectTopic(existingIndex);
      return;
    }

    _rememberPosition();
    _extraCategories = [..._extraCategories, normalized];
    _topicIndex = topics.length - 1;
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
  }

  void selectCategory(int index) => selectTopic(index);

  void setExtraCategories(List<String> categories) {
    _rememberPosition();
    _extraCategories = List.of(categories);
    if (_topicIndex >= topics.length) _topicIndex = 0;
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
  }

  void setFollowedPaperIds(Iterable<String> paperIds) {
    final next = paperIds.toSet();
    if (setEquals(next, _followedPaperIds)) return;
    _followedPaperIds = next;
    if (_primaryCategoryIndex != PaperFeedMode.following.index) return;
    _rememberPosition();
    _restorePosition();
    notifyListeners();
  }

  void _rememberPosition() {
    if (_visiblePapers.isNotEmpty) {
      _positions[_filterKey] = _currentPaperIndex;
    }
  }

  void _restorePosition() {
    _refreshVisiblePapers();
    if (_visiblePapers.isEmpty) {
      _currentPaperIndex = 0;
      return;
    }
    _currentPaperIndex =
        (_positions[_filterKey] ?? 0).clamp(0, _visiblePapers.length - 1);
  }

  void _refreshVisiblePapers() {
    _visiblePapers = PaperFeedFilter.apply(
      papers: _allPapers,
      mode: PaperFeedMode.values[_primaryCategoryIndex],
      topic: topics[_topicIndex],
      followedPaperIds: _followedPaperIds,
    );
  }

  void _applyCatalogPage(PaperPage page, {required bool append}) {
    final currentPaperId = _visiblePapers.isEmpty
        ? null
        : _visiblePapers[_currentPaperIndex.clamp(
            0,
            _visiblePapers.length - 1,
          )]
            .id;
    if (append) {
      final byId = {for (final paper in _allPapers) paper.id: paper};
      for (final paper in page.papers) {
        byId[paper.id] = paper;
      }
      _allPapers = List.unmodifiable(byId.values);
    } else if (page.papers.isNotEmpty) {
      _allPapers = List.unmodifiable(page.papers);
    }
    _catalogNextOffset = page.nextOffset;
    _catalogOffline = page.isOffline;
    _catalogStale = page.isStale;
    _catalogError = page.error;
    _refreshVisiblePapers();
    if (_visiblePapers.isEmpty) {
      _currentPaperIndex = 0;
      return;
    }
    final restoredIndex = currentPaperId == null
        ? -1
        : _visiblePapers.indexWhere((paper) => paper.id == currentPaperId);
    _currentPaperIndex = restoredIndex >= 0
        ? restoredIndex
        : _currentPaperIndex.clamp(0, _visiblePapers.length - 1);
  }

  String get _filterKey => _primaryCategoryIndex == 0
      ? '$_primaryCategoryIndex:$_topicIndex'
      : '$_primaryCategoryIndex';

  Future<void> flushPreferenceWrites() => _preferenceWriteQueue;

  Future<void> reloadPreferences() async {
    await flushPreferenceWrites();
    _extraCategories = [];
    _positions.clear();
    _primaryCategoryIndex = 0;
    _topicIndex = 0;
    _currentPaperIndex = 0;
    final repository = _preferenceRepository;
    if (repository == null) {
      _refreshVisiblePapers();
      notifyListeners();
      return;
    }
    await initializePreferences();
  }

  void _queuePreferencePersistence() {
    final repository = _preferenceRepository;
    if (repository == null) return;
    final preferences = PaperPreferences(
      extraTopics: _extraCategories,
      positions: _positions,
      primaryCategoryIndex: _primaryCategoryIndex,
      topicIndex: _topicIndex,
    );
    _preferenceWriteQueue = _preferenceWriteQueue.then((_) async {
      try {
        await repository.save(preferences);
        _preferenceError = null;
      } on PaperPreferencePersistenceException catch (error) {
        _preferenceError = error.message;
      }
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
