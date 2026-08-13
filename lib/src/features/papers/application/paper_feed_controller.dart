import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/paper.dart';
import '../domain/paper_catalog.dart';
import '../domain/paper_channel.dart';
import '../domain/paper_channel_preference_repository.dart';
import '../domain/paper_feed_filter.dart';
import '../domain/paper_preference_repository.dart';
import '../domain/paper_repository.dart';
import '../domain/paper_time_range.dart';
import 'paper_feed_preference_coordinator.dart';
import 'paper_feed_projector.dart';

class PaperFeedController extends ChangeNotifier {
  PaperFeedController(
    PaperRepository repository, {
    PaperPreferenceRepository? preferenceRepository,
    PaperCatalogRepository? catalogRepository,
    PaperChannelPreferenceRepository? channelPreferenceRepository,
    Iterable<String> Function()? readPaperIdsProvider,
    ValueListenable<Set<String>>? followedPaperIdsListenable,
  }) : this.fromPapers(
          repository.getAll(),
          preferenceRepository: preferenceRepository,
          catalogRepository: catalogRepository,
          channelPreferenceRepository: channelPreferenceRepository,
          readPaperIdsProvider: readPaperIdsProvider,
          followedPaperIdsListenable: followedPaperIdsListenable,
        );

  PaperFeedController.fromPapers(
    Iterable<Paper> papers, {
    PaperPreferenceRepository? preferenceRepository,
    PaperCatalogRepository? catalogRepository,
    PaperChannelPreferenceRepository? channelPreferenceRepository,
    Iterable<String> Function()? readPaperIdsProvider,
    ValueListenable<Set<String>>? followedPaperIdsListenable,
  })  : _allPapers = List.unmodifiable(papers),
        _catalogRepository = catalogRepository,
        _readPaperIdsProvider = readPaperIdsProvider,
        _followedPaperIdsListenable = followedPaperIdsListenable,
        _preferences = PaperFeedPreferenceCoordinator(
          preferenceRepository: preferenceRepository,
          channelPreferenceRepository: channelPreferenceRepository,
        ) {
    _initialPapers = _allPapers;
    _preferences.onChanged = _notify;
    _followedPaperIdsListenable?.addListener(_handleFollowedPaperIdsChanged);
    _refreshVisiblePapers();
  }

  static const _defaultArxivCategories =
      'cs.CL|cs.AI|cs.CV|cs.DC|cs.OS|cs.PF|math.OC|math.ST|q-bio.QM|q-bio.BM';
  static const _catalogPrefetchThreshold = 10;
  static const _maxReadPaperIdsPerRequest = 200;

  List<Paper> _allPapers;
  late final List<Paper> _initialPapers;
  late List<Paper> _visiblePapers;
  final PaperCatalogRepository? _catalogRepository;
  final Iterable<String> Function()? _readPaperIdsProvider;
  final ValueListenable<Set<String>>? _followedPaperIdsListenable;
  final PaperFeedPreferenceCoordinator _preferences;
  final Set<String> _loadedChannelKeys = {};
  final Map<String, List<Paper>> _channelPapers = {};
  final Map<String, _CatalogChannelState> _catalogStates = {};
  int _channelIndex = 0;
  int _currentPaperIndex = 0;
  bool _gridMode = false;
  bool _catalogLoading = false;
  bool _catalogLoadingMore = false;
  final Set<Future<void>> _catalogOperations = {};
  int _catalogQueryRevision = 0;
  bool _disposed = false;

  List<Paper> get papers => _visiblePapers;
  List<Paper> get allPapers => _allPapers;
  List<UserPaperChannel> get userChannels => _preferences.userChannels;
  int get channelCount =>
      FixedPaperChannel.values.length + _preferences.userChannels.length;
  int get channelIndex => _channelIndex;
  int get primaryCategoryIndex => _channelMode.index;
  int get currentPaperIndex => _currentPaperIndex;
  bool get gridMode => _gridMode;
  String? get preferenceError => _preferences.preferenceError;
  String? get channelPreferenceError => _preferences.channelPreferenceError;
  bool get catalogLoading => _catalogLoading;
  bool get catalogLoadingMore => _catalogLoadingMore;
  bool get catalogOffline => _currentCatalogState?.offline ?? false;
  bool get catalogStale => _currentCatalogState?.stale ?? false;
  PaperPageSource get catalogSource =>
      _currentCatalogState?.source ?? PaperPageSource.seed;
  DateTime? get catalogFetchedAt => _currentCatalogState?.fetchedAt;
  bool get catalogHasMore => _currentCatalogState?.hasMore ?? false;
  PaperCatalogError? get catalogError => _currentCatalogState?.error;
  PaperTimeRange get timeRange => _preferences.timeRangeFor(currentChannelKey);

  Set<String> get _currentFollowedPaperIds =>
      _followedPaperIdsListenable?.value ?? const <String>{};

  _CatalogChannelState? get _currentCatalogState =>
      _catalogStates[currentChannelKey];

  String get currentChannelKey => channelKeyAt(_channelIndex);

  String channelKeyAt(int index) {
    final fixedCount = FixedPaperChannel.values.length;
    if (index < fixedCount) {
      return 'fixed:${FixedPaperChannel.values[index].name}';
    }
    return _preferences.userChannels[index - fixedCount].storageKey;
  }

  UserPaperChannel? userChannelAt(int index) {
    final fixedCount = FixedPaperChannel.values.length;
    if (index < fixedCount || index >= channelCount) return null;
    return _preferences.userChannels[index - fixedCount];
  }

  Future<void> initializeCatalog() => refreshCatalog(forceRefresh: false);

  Future<void> initializeChannels() async {
    if (_disposed) return;
    await _preferences.initializeChannelPreferences();
    if (_disposed) return;
    _applySelectedChannelKey(_preferences.selectedChannelKey);
    _restorePosition();
    _notify();
  }

  Future<void> refreshCatalog({bool forceRefresh = true}) {
    final repository = _catalogRepository;
    if (_disposed ||
        repository == null ||
        _catalogLoading ||
        !_canLoadCurrentChannel) {
      return Future.value();
    }
    final channelKey = currentChannelKey;
    final queryRevision = _advanceCatalogQueryRevision();
    final query = PaperFeedQuery(
      channel: _catalogChannel,
      category: _catalogCategory,
      followingAuthors: _followingAuthors,
      readPaperIds: _readPaperIdsForRequest(),
      timeRange: timeRange,
      limit: 20,
      forceRefresh: forceRefresh,
    );
    return _trackCatalogOperation(
      _refreshCatalog(
        repository,
        channelKey: channelKey,
        query: query,
        queryRevision: queryRevision,
      ),
    );
  }

  Future<void> _refreshCatalog(
    PaperCatalogRepository repository, {
    required String channelKey,
    required PaperFeedQuery query,
    required int queryRevision,
  }) async {
    _catalogLoading = true;
    _notify();
    try {
      final page = await repository.loadFeed(query);
      if (!_disposed && queryRevision == _catalogQueryRevision) {
        _applyCatalogPage(
          page,
          channelKey: channelKey,
          append: _loadedChannelKeys.contains(channelKey),
        );
      }
    } on Object catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.paperFeedRefresh,
        error: error,
        stackTrace: stackTrace,
      );
      if (!_disposed && queryRevision == _catalogQueryRevision) {
        _catalogStateFor(channelKey).error = const PaperCatalogError(
          kind: PaperCatalogErrorKind.unavailable,
          message: '论文目录暂时不可用，请稍后重试。',
        );
      }
    } finally {
      _catalogLoading = false;
      _notify();
      if (!_disposed &&
          queryRevision != _catalogQueryRevision &&
          _canLoadCurrentChannel) {
        _ensureCurrentChannelLoaded();
      }
    }
  }

  Future<void> loadMoreCatalog() {
    final repository = _catalogRepository;
    final channelKey = currentChannelKey;
    final state = _catalogStates[channelKey];
    final nextOffset = state?.nextOffset;
    final nextCursor = state?.nextCursor;
    if (_disposed ||
        repository == null ||
        (nextOffset == null && nextCursor == null) ||
        _catalogLoading ||
        _catalogLoadingMore) {
      return Future.value();
    }
    final queryRevision = _catalogQueryRevision;
    final query = PaperFeedQuery(
      channel: _catalogChannel,
      category: _catalogCategory,
      followingAuthors: _followingAuthors,
      readPaperIds: _readPaperIdsForRequest(),
      timeRange: timeRange,
      offset: nextOffset ?? 0,
      cursor: nextCursor,
      limit: 20,
    );
    return _trackCatalogOperation(
      _loadMoreCatalog(
        repository,
        channelKey: channelKey,
        query: query,
        queryRevision: queryRevision,
      ),
    );
  }

  Future<void> _loadMoreCatalog(
    PaperCatalogRepository repository, {
    required String channelKey,
    required PaperFeedQuery query,
    required int queryRevision,
  }) async {
    _catalogLoadingMore = true;
    _notify();
    try {
      final page = await repository.loadFeed(query);
      if (!_disposed && queryRevision == _catalogQueryRevision) {
        _applyCatalogPage(page, channelKey: channelKey, append: true);
      }
    } on Object catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.paperFeedLoadMore,
        error: error,
        stackTrace: stackTrace,
      );
      if (!_disposed && queryRevision == _catalogQueryRevision) {
        _catalogStateFor(channelKey).error = const PaperCatalogError(
          kind: PaperCatalogErrorKind.unavailable,
          message: '无法加载更多论文，请稍后重试。',
        );
      }
    } finally {
      if (queryRevision == _catalogQueryRevision) {
        _catalogLoadingMore = false;
        _notify();
      }
    }
  }

  Future<void> initializePreferences() async {
    if (_disposed) return;
    await _preferences.initializeFeedPreferences();
    if (_disposed) return;
    _restorePosition();
    _notify();
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
    final paper =
        _allPapers.where((candidate) => candidate.id == paperId).firstOrNull;
    if (paper == null) return;
    _rememberPosition();
    _channelIndex = 0;
    final key = currentChannelKey;
    final list = List<Paper>.of(_papersForChannel(key));
    var index = list.indexWhere((candidate) => candidate.id == paperId);
    if (index < 0) {
      list.insert(0, paper);
      index = 0;
    }
    _channelPapers[key] = List.unmodifiable(list);
    _refreshVisiblePapers();
    _currentPaperIndex = index.clamp(0, _visiblePapers.length - 1);
    _preferences.rememberPosition(currentChannelKey, _currentPaperIndex);
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
      _preferences.rememberPosition(currentChannelKey, index);
      notifyListeners();
      _queuePreferencePersistence();
    }
    _prefetchCatalogForIndex(index);
  }

  void selectPrimaryCategory(int index) => selectChannel(index);

  void selectTimeRange(PaperTimeRange range) {
    if (range.storageKey == timeRange.storageKey) return;
    final key = currentChannelKey;
    _preferences.selectTimeRange(key, range);
    _currentPaperIndex = 0;
    _catalogStates.remove(key);
    _loadedChannelKeys.remove(key);
    _channelPapers.remove(key);
    _advanceCatalogQueryRevision();
    _refreshVisiblePapers();
    notifyListeners();
    _queuePreferencePersistence();
    if (_canLoadCurrentChannel) {
      _ensureCurrentChannelLoaded();
    }
  }

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
    _advanceCatalogQueryRevision();
    if (_canLoadCurrentChannel) {
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
    _rememberPosition();
    final selectedKey = currentChannelKey;
    _preferences.replaceUserChannels(channels);
    final selectionStillExists = selectedKey.startsWith('fixed:') ||
        _preferences.hasUserChannel(selectedKey);
    if (!selectionStillExists) {
      _channelIndex = 0;
    } else {
      _applySelectedChannelKey(selectedKey);
    }
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
    _queueChannelPreferencePersistence();
    _advanceCatalogQueryRevision();
    if (_canLoadCurrentChannel) {
      _ensureCurrentChannelLoaded();
    }
  }

  bool hasUserChannel(String storageKey) =>
      _preferences.hasUserChannel(storageKey);

  void _handleFollowedPaperIdsChanged() {
    if (_disposed) return;
    final followingIsActive = _channelMode == PaperFeedMode.following;
    if (followingIsActive) _rememberPosition();
    final key = channelKeyAt(FixedPaperChannel.following.index);
    _catalogStates.remove(key);
    _loadedChannelKeys.remove(key);
    _channelPapers.remove(key);
    if (!followingIsActive) return;
    _advanceCatalogQueryRevision();
    _restorePosition();
    notifyListeners();
    if (_canLoadCurrentChannel) _ensureCurrentChannelLoaded();
  }

  void _applySelectedChannelKey(String? key) {
    if (key == null) {
      _channelIndex = _preferences.legacyPrimaryIndex;
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
      _preferences.rememberPosition(currentChannelKey, _currentPaperIndex);
    }
  }

  void _restorePosition() {
    _refreshVisiblePapers();
    if (_visiblePapers.isEmpty) {
      _currentPaperIndex = 0;
      return;
    }
    _currentPaperIndex = _preferences
        .positionFor(currentChannelKey)
        .clamp(0, _visiblePapers.length - 1);
  }

  void _refreshVisiblePapers() {
    if (_channelMode == PaperFeedMode.following) {
      _visiblePapers = PaperFeedFilter.apply(
        papers: _allPapers,
        mode: PaperFeedMode.following,
        followedPaperIds: _currentFollowedPaperIds,
        timeRange: timeRange,
      );
      return;
    }
    _visiblePapers = List.unmodifiable(_papersForChannel(currentChannelKey));
  }

  List<Paper> _papersForChannel(String channelKey) {
    return _channelPapers[channelKey] ?? _fallbackPapersFor(channelKey);
  }

  List<Paper> _fallbackPapersFor(String channelKey) {
    return PaperFeedProjector.fallback(
      papers: _allPapers,
      channelKey: channelKey,
      mode: _channelMode,
      followedPaperIds: _currentFollowedPaperIds,
      timeRange: timeRange,
    );
  }

  void _applyCatalogPage(
    PaperPage page, {
    required String channelKey,
    required bool append,
  }) {
    if (!append) {
      _loadedChannelKeys.add(channelKey);
    }
    final currentPaperId = _visiblePapers.isEmpty
        ? null
        : _visiblePapers[_currentPaperIndex.clamp(0, _visiblePapers.length - 1)]
            .id;
    // Replace seed papers after the first successful remote page. Later
    // refreshes append to the loaded remote buffer.
    final existing = append
        ? _papersForChannel(channelKey)
        : (_channelPapers[channelKey] ?? const <Paper>[]);
    _channelPapers[channelKey] = PaperFeedProjector.mergeCatalogPage(
      existing: existing,
      incoming: page.papers,
      append: append,
    );
    if (page.papers.isNotEmpty) {
      final poolById = <String, Paper>{
        for (final paper in _allPapers) paper.id: paper,
        for (final paper in page.papers) paper.id: paper,
      };
      _allPapers = List.unmodifiable(poolById.values);
    }
    _catalogStateFor(channelKey).apply(page);
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

  void _prefetchCatalogForIndex(int index) {
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

  String? get _catalogCategory {
    final userChannel = userChannelAt(_channelIndex);
    if (userChannel != null) return userChannel.id;
    if (_channelMode == PaperFeedMode.following) return null;
    return _defaultArxivCategories;
  }

  PaperFeedChannel get _catalogChannel {
    final userChannel = userChannelAt(_channelIndex);
    if (userChannel != null) {
      return switch (userChannel.kind) {
        PaperChannelKind.subject => PaperFeedChannel.subject,
        PaperChannelKind.conference => PaperFeedChannel.conference,
      };
    }
    return switch (_channelMode) {
      PaperFeedMode.recommended => PaperFeedChannel.recommended,
      PaperFeedMode.following => PaperFeedChannel.following,
      PaperFeedMode.latest => PaperFeedChannel.latest,
    };
  }

  List<String> get _followingAuthors {
    final authors = <String>{};
    for (final identity in _currentFollowedPaperIds) {
      if (identity.startsWith('author:')) {
        final author = identity.substring('author:'.length).trim();
        if (author.isNotEmpty) authors.add(author);
        continue;
      }
      for (final paper in _allPapers) {
        if (paper.id != identity) continue;
        final author = paper.firstAuthor.trim().toLowerCase();
        if (author.isNotEmpty) authors.add(author);
        break;
      }
    }
    return authors.toList(growable: false)..sort();
  }

  List<String> _readPaperIdsForRequest() {
    if (_channelMode != PaperFeedMode.recommended) return const [];
    final seen = <String>{};
    final excluded = <String>[];
    void add(String value) {
      final paperId = value.trim();
      if (paperId.isNotEmpty && seen.add(paperId)) excluded.add(paperId);
    }

    for (final paper in _channelPapers[currentChannelKey] ?? const <Paper>[]) {
      add(paper.id);
    }
    final readIds = (_readPaperIdsProvider?.call() ?? const <String>[])
        .map((paperId) => paperId.trim())
        .where((paperId) => paperId.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    readIds.forEach(add);
    return excluded.take(_maxReadPaperIdsPerRequest).toList(growable: false);
  }

  bool get _canLoadCurrentChannel =>
      _channelMode != PaperFeedMode.following || _followingAuthors.isNotEmpty;

  Future<void> flushPreferenceWrites() => _preferences.flushFeedWrites();

  Future<void> flushChannelPreferenceWrites() =>
      _preferences.flushChannelWrites();

  Future<void> flushCatalogOperations() async {
    while (_catalogOperations.isNotEmpty) {
      await Future.wait(_catalogOperations.toList(growable: false));
    }
  }

  Future<void> _trackCatalogOperation(Future<void> operation) {
    late final Future<void> tracked;
    tracked = operation.whenComplete(() => _catalogOperations.remove(tracked));
    _catalogOperations.add(tracked);
    return tracked;
  }

  Future<void> reloadPreferences() async {
    await flushCatalogOperations();
    if (_disposed) return;
    await flushPreferenceWrites();
    if (_disposed) return;
    await flushChannelPreferenceWrites();
    if (_disposed) return;
    _preferences.reset();
    _loadedChannelKeys.clear();
    _channelPapers.clear();
    _catalogStates.clear();
    _allPapers = _initialPapers;
    _channelIndex = 0;
    _currentPaperIndex = 0;
    _advanceCatalogQueryRevision();
    if (!_preferences.hasRepositories) {
      _refreshVisiblePapers();
      _notify();
    } else {
      await initializePreferences();
      await initializeChannels();
    }
    if (!_disposed && _canLoadCurrentChannel) {
      await refreshCatalog(forceRefresh: false);
    }
  }

  _CatalogChannelState _catalogStateFor(String channelKey) =>
      _catalogStates.putIfAbsent(channelKey, _CatalogChannelState.new);

  int _advanceCatalogQueryRevision() {
    _catalogLoadingMore = false;
    return ++_catalogQueryRevision;
  }

  void _queuePreferencePersistence() {
    _preferences.queueFeedPersistence(primaryCategoryIndex: _channelMode.index);
  }

  void _queueChannelPreferencePersistence() {
    _preferences.selectChannel(currentChannelKey);
    _preferences.queueChannelPersistence();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _followedPaperIdsListenable?.removeListener(
      _handleFollowedPaperIdsChanged,
    );
    _preferences.dispose();
    super.dispose();
  }
}

class _CatalogChannelState {
  int? nextOffset;
  String? nextCursor;
  bool offline = false;
  bool stale = false;
  PaperPageSource source = PaperPageSource.seed;
  DateTime? fetchedAt;
  PaperCatalogError? error;

  bool get hasMore => nextOffset != null || nextCursor != null;

  void apply(PaperPage page) {
    nextOffset = page.nextOffset;
    nextCursor = page.nextCursor;
    offline = page.isOffline;
    stale = page.isStale;
    source = page.source;
    fetchedAt = page.fetchedAt;
    error = page.error;
  }
}
