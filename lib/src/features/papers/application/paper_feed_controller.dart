import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/paper.dart';
import '../domain/paper_catalog.dart';
import '../domain/paper_channel.dart';
import '../domain/paper_channel_preference_repository.dart';
import '../domain/paper_feed_filter.dart';
import '../domain/paper_preference_repository.dart';
import '../domain/paper_repository.dart';

class PaperFeedController extends ChangeNotifier {
  PaperFeedController(
    PaperRepository repository, {
    PaperPreferenceRepository? preferenceRepository,
    PaperCatalogRepository? catalogRepository,
    PaperChannelPreferenceRepository? channelPreferenceRepository,
  }) : this.fromPapers(
          repository.getAll(),
          preferenceRepository: preferenceRepository,
          catalogRepository: catalogRepository,
          channelPreferenceRepository: channelPreferenceRepository,
        );

  PaperFeedController.fromPapers(
    Iterable<Paper> papers, {
    PaperPreferenceRepository? preferenceRepository,
    PaperCatalogRepository? catalogRepository,
    PaperChannelPreferenceRepository? channelPreferenceRepository,
  })  : _allPapers = List.unmodifiable(papers),
        _preferenceRepository = preferenceRepository,
        _catalogRepository = catalogRepository,
        _channelPreferenceRepository = channelPreferenceRepository {
    _refreshVisiblePapers();
  }

  static const _defaultArxivCategories =
      'cs.CL|cs.AI|cs.CV|cs.DC|cs.OS|cs.PF|math.OC|math.ST|q-bio.QM|q-bio.BM';
  static const _catalogPrefetchThreshold = 10;

  List<Paper> _allPapers;
  late List<Paper> _visiblePapers;
  Set<String> _followedPaperIds = {};
  final PaperPreferenceRepository? _preferenceRepository;
  final PaperCatalogRepository? _catalogRepository;
  final PaperChannelPreferenceRepository? _channelPreferenceRepository;
  Future<void> _preferenceWriteQueue = Future.value();
  Future<void> _channelPreferenceWriteQueue = Future.value();
  String? _preferenceError;
  String? _channelPreferenceError;
  final Map<String, int> _positions = {};
  final Set<String> _loadedChannelKeys = {};
  List<UserPaperChannel> _userChannels = const [];
  int _channelIndex = 0;
  int _legacyPrimaryIndex = 0;
  int _currentPaperIndex = 0;
  bool _gridMode = false;
  bool _catalogLoading = false;
  bool _catalogLoadingMore = false;
  bool _catalogOffline = false;
  bool _catalogStale = false;
  PaperPageSource _catalogSource = PaperPageSource.seed;
  DateTime? _catalogFetchedAt;
  final Set<Future<void>> _catalogOperations = {};
  int _catalogQueryRevision = 0;
  int? _catalogNextOffset;
  PaperCatalogError? _catalogError;
  bool _disposed = false;

  List<Paper> get papers => _visiblePapers;
  List<Paper> get allPapers => _allPapers;
  List<UserPaperChannel> get userChannels => List.unmodifiable(_userChannels);
  int get channelCount =>
      FixedPaperChannel.values.length + _userChannels.length;
  int get channelIndex => _channelIndex;
  int get primaryCategoryIndex => _channelMode.index;
  int get currentPaperIndex => _currentPaperIndex;
  bool get gridMode => _gridMode;
  String? get preferenceError => _preferenceError;
  String? get channelPreferenceError => _channelPreferenceError;
  bool get catalogLoading => _catalogLoading;
  bool get catalogLoadingMore => _catalogLoadingMore;
  bool get catalogOffline => _catalogOffline;
  bool get catalogStale => _catalogStale;
  PaperPageSource get catalogSource => _catalogSource;
  DateTime? get catalogFetchedAt => _catalogFetchedAt;
  bool get catalogHasMore => _catalogNextOffset != null;
  PaperCatalogError? get catalogError => _catalogError;

  String get currentChannelKey => channelKeyAt(_channelIndex);

  String channelKeyAt(int index) {
    final fixedCount = FixedPaperChannel.values.length;
    if (index < fixedCount) {
      return 'fixed:${FixedPaperChannel.values[index].name}';
    }
    return _userChannels[index - fixedCount].storageKey;
  }

  UserPaperChannel? userChannelAt(int index) {
    final fixedCount = FixedPaperChannel.values.length;
    if (index < fixedCount || index >= channelCount) return null;
    return _userChannels[index - fixedCount];
  }

  Future<void> initializeCatalog() => refreshCatalog(forceRefresh: false);

  Future<void> initializeChannels() async {
    final repository = _channelPreferenceRepository;
    if (repository == null) {
      _applySelectedChannelKey(null);
      _restorePosition();
      notifyListeners();
      return;
    }
    try {
      final preferences = await repository.load();
      _userChannels = preferences.userChannels;
      _applySelectedChannelKey(preferences.selectedChannelKey);
      _channelPreferenceError = null;
    } on PaperChannelPreferencePersistenceException catch (error) {
      _channelPreferenceError = error.message;
    }
    _restorePosition();
    notifyListeners();
  }

  Future<void> refreshCatalog({bool forceRefresh = true}) {
    final repository = _catalogRepository;
    if (repository == null ||
        _catalogLoading ||
        _channelMode == PaperFeedMode.following) {
      return Future.value();
    }
    return _trackCatalogOperation(
      _refreshCatalog(repository, forceRefresh: forceRefresh),
    );
  }

  Future<void> _refreshCatalog(
    PaperCatalogRepository repository, {
    required bool forceRefresh,
  }) async {
    final queryRevision = _catalogQueryRevision;
    _catalogLoading = true;
    notifyListeners();
    try {
      final page = await repository.loadFeed(
        PaperFeedQuery(
          category: _catalogCategory,
          limit: 20,
          forceRefresh: forceRefresh,
        ),
      );
      if (queryRevision == _catalogQueryRevision) {
        _applyCatalogPage(page, append: false);
      }
    } on Object catch (_) {
      if (queryRevision == _catalogQueryRevision) {
        _catalogError = const PaperCatalogError(
          kind: PaperCatalogErrorKind.unavailable,
          message: '论文目录暂时不可用，请稍后重试。',
        );
      }
    } finally {
      _catalogLoading = false;
      if (!_disposed) notifyListeners();
      if (!_disposed &&
          queryRevision != _catalogQueryRevision &&
          _channelMode != PaperFeedMode.following) {
        _ensureCurrentChannelLoaded();
      }
    }
  }

  Future<void> loadMoreCatalog() {
    final repository = _catalogRepository;
    final nextOffset = _catalogNextOffset;
    if (repository == null ||
        nextOffset == null ||
        _catalogLoading ||
        _catalogLoadingMore ||
        _channelMode == PaperFeedMode.following) {
      return Future.value();
    }
    return _trackCatalogOperation(
      _loadMoreCatalog(repository, nextOffset),
    );
  }

  Future<void> _loadMoreCatalog(
    PaperCatalogRepository repository,
    int nextOffset,
  ) async {
    final queryRevision = _catalogQueryRevision;
    _catalogLoadingMore = true;
    notifyListeners();
    try {
      final page = await repository.loadFeed(
        PaperFeedQuery(
          category: _catalogCategory,
          offset: nextOffset,
          limit: 20,
        ),
      );
      if (queryRevision == _catalogQueryRevision) {
        _applyCatalogPage(page, append: true);
      }
    } on Object catch (_) {
      if (queryRevision == _catalogQueryRevision) {
        _catalogError = const PaperCatalogError(
          kind: PaperCatalogErrorKind.unavailable,
          message: '无法加载更多论文，请稍后重试。',
        );
      }
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
      _positions
        ..clear()
        ..addAll(preferences.positions);
      _legacyPrimaryIndex = preferences.primaryCategoryIndex.clamp(
        0,
        FixedPaperChannel.values.length - 1,
      );
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
    _prefetchCatalogForIndex(index);
  }

  void openPaperById(String paperId) {
    final exists = _allPapers.any((paper) => paper.id == paperId);
    if (!exists) return;
    _rememberPosition();
    _channelIndex = 0;
    _refreshVisiblePapers();
    _currentPaperIndex =
        _visiblePapers.indexWhere((paper) => paper.id == paperId);
    _positions[currentChannelKey] = _currentPaperIndex;
    _gridMode = false;
    notifyListeners();
    _queuePreferencePersistence();
  }

  void selectPaper(int index) {
    if (index < 0 || index >= _visiblePapers.length) {
      return;
    }
    if (index != _currentPaperIndex) {
      _currentPaperIndex = index;
      _positions[currentChannelKey] = index;
      notifyListeners();
      _queuePreferencePersistence();
    }
    _prefetchCatalogForIndex(index);
  }

  void selectPrimaryCategory(int index) => selectChannel(index);

  void selectChannel(int index) {
    if (index == _channelIndex || index < 0 || index >= channelCount) {
      return;
    }
    _rememberPosition();
    _channelIndex = index;
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
    _queueChannelPreferencePersistence();
    _catalogQueryRevision++;
    if (_channelMode != PaperFeedMode.following) {
      _ensureCurrentChannelLoaded();
    }
  }

  /// 频道首次进入时按需拉取；已加载的频道不重复请求，
  /// 强制刷新只由用户下拉触发。
  void _ensureCurrentChannelLoaded() {
    if (_loadedChannelKeys.contains(currentChannelKey)) return;
    unawaited(refreshCatalog(forceRefresh: false));
  }

  Future<void> saveUserChannels(List<UserPaperChannel> channels) async {
    final seen = <String>{};
    final unique = channels
        .where((channel) => seen.add(channel.storageKey))
        .toList(growable: false);
    _rememberPosition();
    final selectedKey = currentChannelKey;
    _userChannels = List.unmodifiable(unique);
    final selectionStillExists = selectedKey.startsWith('fixed:') ||
        _userChannels.any((channel) => channel.storageKey == selectedKey);
    if (!selectionStillExists) {
      _channelIndex = 0;
    } else {
      _applySelectedChannelKey(selectedKey);
    }
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
    _queueChannelPreferencePersistence();
    _catalogQueryRevision++;
    if (_channelMode != PaperFeedMode.following) {
      _ensureCurrentChannelLoaded();
    }
  }

  bool hasUserChannel(String storageKey) =>
      _userChannels.any((channel) => channel.storageKey == storageKey);

  void setFollowedPaperIds(Iterable<String> paperIds) {
    final next = paperIds.toSet();
    if (setEquals(next, _followedPaperIds)) return;
    _followedPaperIds = next;
    if (_channelMode != PaperFeedMode.following) return;
    _rememberPosition();
    _restorePosition();
    notifyListeners();
  }

  void _applySelectedChannelKey(String? key) {
    if (key == null) {
      _channelIndex = _legacyPrimaryIndex;
      return;
    }
    for (var index = 0; index < channelCount; index++) {
      if (channelKeyAt(index) == key) {
        _channelIndex = index;
        return;
      }
    }
    _channelIndex = 0;
  }

  void _rememberPosition() {
    if (_visiblePapers.isNotEmpty) {
      _positions[currentChannelKey] = _currentPaperIndex;
    }
  }

  void _restorePosition() {
    _refreshVisiblePapers();
    if (_visiblePapers.isEmpty) {
      _currentPaperIndex = 0;
      return;
    }
    _currentPaperIndex = (_positions[currentChannelKey] ?? 0)
        .clamp(0, _visiblePapers.length - 1);
  }

  void _refreshVisiblePapers() {
    _visiblePapers = PaperFeedFilter.apply(
      papers: _allPapers,
      mode: _channelMode,
      subjectCode: _channelSubjectCode,
      followedPaperIds: _followedPaperIds,
    );
  }

  void _applyCatalogPage(PaperPage page, {required bool append}) {
    if (!append) {
      _loadedChannelKeys.add(currentChannelKey);
    }
    final currentPaperId = _visiblePapers.isEmpty
        ? null
        : _visiblePapers[_currentPaperIndex.clamp(
            0,
            _visiblePapers.length - 1,
          )]
            .id;
    if (page.papers.isNotEmpty) {
      _allPapers = _mergeCatalogPapers(page.papers, append: append);
    }
    _catalogNextOffset = page.nextOffset;
    _catalogOffline = page.isOffline;
    _catalogStale = page.isStale;
    _catalogSource = page.source;
    _catalogFetchedAt = page.fetchedAt;
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

  List<Paper> _mergeCatalogPapers(
    List<Paper> incoming, {
    required bool append,
  }) {
    final latestById = <String, Paper>{
      for (final paper in _allPapers) paper.id: paper,
      for (final paper in incoming) paper.id: paper,
    };
    final orderedIds = append
        ? [
            ..._allPapers.map((paper) => paper.id),
            ...incoming.map((paper) => paper.id),
          ]
        : [
            ...incoming.map((paper) => paper.id),
            ..._allPapers.map((paper) => paper.id),
          ];
    final seen = <String>{};
    return List.unmodifiable([
      for (final id in orderedIds)
        if (seen.add(id)) latestById[id]!,
    ]);
  }

  void _prefetchCatalogForIndex(int index) {
    if (_channelMode == PaperFeedMode.following) return;
    final remaining = _visiblePapers.length - index - 1;
    if (remaining <= _catalogPrefetchThreshold) {
      unawaited(loadMoreCatalog());
    }
  }

  PaperFeedMode get _channelMode {
    if (_channelIndex == FixedPaperChannel.following.index) {
      return PaperFeedMode.following;
    }
    if (_channelIndex == FixedPaperChannel.latest.index) {
      return PaperFeedMode.latest;
    }
    return PaperFeedMode.recommended;
  }

  String? get _channelSubjectCode {
    final channel = userChannelAt(_channelIndex);
    if (channel == null || channel.kind != PaperChannelKind.subject) {
      return null;
    }
    return channel.id;
  }

  String? get _catalogCategory {
    if (_channelMode == PaperFeedMode.following) return null;
    return _channelSubjectCode ?? _defaultArxivCategories;
  }

  Future<void> flushPreferenceWrites() => _preferenceWriteQueue;

  Future<void> flushChannelPreferenceWrites() => _channelPreferenceWriteQueue;

  Future<void> flushCatalogOperations() async {
    while (_catalogOperations.isNotEmpty) {
      await Future.wait(_catalogOperations.toList(growable: false));
    }
  }

  Future<void> _trackCatalogOperation(Future<void> operation) {
    _catalogOperations.add(operation);
    operation.whenComplete(() => _catalogOperations.remove(operation));
    return operation;
  }

  Future<void> reloadPreferences() async {
    await flushPreferenceWrites();
    await flushChannelPreferenceWrites();
    _positions.clear();
    _loadedChannelKeys.clear();
    _userChannels = const [];
    _channelIndex = 0;
    _legacyPrimaryIndex = 0;
    _currentPaperIndex = 0;
    final hasRepository =
        _preferenceRepository != null || _channelPreferenceRepository != null;
    if (!hasRepository) {
      _refreshVisiblePapers();
      notifyListeners();
      return;
    }
    await initializePreferences();
    await initializeChannels();
  }

  void _queuePreferencePersistence() {
    final repository = _preferenceRepository;
    if (repository == null) return;
    final preferences = PaperPreferences(
      positions: _positions,
      primaryCategoryIndex: _channelMode.index,
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

  void _queueChannelPreferencePersistence() {
    final repository = _channelPreferenceRepository;
    if (repository == null) return;
    final preferences = PaperChannelPreferences(
      userChannels: _userChannels,
      selectedChannelKey: currentChannelKey,
    );
    _channelPreferenceWriteQueue = _channelPreferenceWriteQueue.then((_) async {
      try {
        await repository.save(preferences);
        _channelPreferenceError = null;
      } on PaperChannelPreferencePersistenceException catch (error) {
        _channelPreferenceError = error.message;
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
