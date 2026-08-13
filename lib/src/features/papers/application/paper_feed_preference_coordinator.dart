import '../../../core/diagnostics/diagnostics.dart';
import '../domain/paper_channel.dart';
import '../domain/paper_channel_preference_repository.dart';
import '../domain/paper_preference_repository.dart';
import '../domain/paper_time_range.dart';

class PaperFeedPreferenceCoordinator {
  PaperFeedPreferenceCoordinator({
    PaperPreferenceRepository? preferenceRepository,
    PaperChannelPreferenceRepository? channelPreferenceRepository,
  })  : _preferenceRepository = preferenceRepository,
        _channelPreferenceRepository = channelPreferenceRepository;

  final PaperPreferenceRepository? _preferenceRepository;
  final PaperChannelPreferenceRepository? _channelPreferenceRepository;
  final Map<String, int> _positions = {};
  final Map<String, PaperTimeRange> _timeRanges = {};

  Future<void> _feedWriteQueue = Future.value();
  Future<void> _channelWriteQueue = Future.value();
  Future<void>? _feedInitialization;
  Future<void>? _channelInitialization;
  final Set<String> _positionsChangedDuringLoad = {};
  final Set<String> _timeRangesChangedDuringLoad = {};
  List<UserPaperChannel> _userChannels = const [];
  String? _selectedChannelKey;
  int _legacyPrimaryIndex = 0;
  int? _deferredPrimaryIndex;
  String? _preferenceError;
  String? _channelPreferenceError;
  bool _feedLoadInProgress = false;
  bool _channelLoadInProgress = false;
  bool _feedPersistenceDeferred = false;
  bool _channelPersistenceDeferred = false;
  bool _userChannelsChangedDuringLoad = false;
  bool _selectedChannelChangedDuringLoad = false;
  bool _disposed = false;

  void Function()? onChanged;

  List<UserPaperChannel> get userChannels => _userChannels;
  String? get selectedChannelKey => _selectedChannelKey;
  int get legacyPrimaryIndex => _legacyPrimaryIndex;
  String? get preferenceError => _preferenceError;
  String? get channelPreferenceError => _channelPreferenceError;
  bool get hasRepositories =>
      _preferenceRepository != null || _channelPreferenceRepository != null;

  int positionFor(String channelKey) => _positions[channelKey] ?? 0;

  PaperTimeRange timeRangeFor(String channelKey) =>
      _timeRanges[channelKey] ?? const PaperTimeRange.all();

  bool hasUserChannel(String storageKey) =>
      _userChannels.any((channel) => channel.storageKey == storageKey);

  Future<void> initializeFeedPreferences() {
    if (_disposed) return Future.value();
    final existing = _feedInitialization;
    if (existing != null) return existing;
    final repository = _preferenceRepository;
    if (repository == null) return Future.value();
    _feedLoadInProgress = true;
    _positionsChangedDuringLoad.clear();
    _timeRangesChangedDuringLoad.clear();
    late final Future<void> operation;
    operation = _loadFeedPreferences(repository).whenComplete(() {
      if (identical(_feedInitialization, operation)) {
        _feedInitialization = null;
      }
    });
    _feedInitialization = operation;
    return operation;
  }

  Future<void> _loadFeedPreferences(
    PaperPreferenceRepository repository,
  ) async {
    try {
      final preferences = await repository.load();
      if (_disposed) return;
      final changedPositions = {
        for (final key in _positionsChangedDuringLoad) key: _positions[key]!,
      };
      final changedTimeRanges = {
        for (final key in _timeRangesChangedDuringLoad) key: _timeRanges[key]!,
      };
      _positions
        ..clear()
        ..addAll(preferences.positions)
        ..addAll(changedPositions);
      _timeRanges
        ..clear()
        ..addEntries(
          preferences.timeRanges.entries.map(
            (entry) => MapEntry(
              entry.key,
              PaperTimeRange.fromStorageKey(entry.value),
            ),
          ),
        )
        ..addAll(changedTimeRanges);
      _legacyPrimaryIndex =
          (_deferredPrimaryIndex ?? preferences.primaryCategoryIndex)
              .clamp(0, FixedPaperChannel.values.length - 1);
      _preferenceError = null;
    } on PaperPreferencePersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperFeedPreferencesLoad,
        error,
        stackTrace,
      );
      if (!_disposed) _preferenceError = error.message;
    } on Object catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperFeedPreferencesLoad,
        error,
        stackTrace,
      );
      if (!_disposed) {
        _preferenceError = '论文浏览偏好读取失败，请稍后重试。';
      }
    } finally {
      _finishFeedLoad();
    }
  }

  Future<void> initializeChannelPreferences() {
    if (_disposed) return Future.value();
    final existing = _channelInitialization;
    if (existing != null) return existing;
    final repository = _channelPreferenceRepository;
    if (repository == null) return Future.value();
    _channelLoadInProgress = true;
    _userChannelsChangedDuringLoad = false;
    _selectedChannelChangedDuringLoad = false;
    late final Future<void> operation;
    operation = _loadChannelPreferences(repository).whenComplete(() {
      if (identical(_channelInitialization, operation)) {
        _channelInitialization = null;
      }
    });
    _channelInitialization = operation;
    return operation;
  }

  Future<void> _loadChannelPreferences(
    PaperChannelPreferenceRepository repository,
  ) async {
    try {
      final preferences = await repository.load();
      if (_disposed) return;
      if (!_userChannelsChangedDuringLoad) {
        _userChannels = preferences.userChannels;
      }
      if (!_selectedChannelChangedDuringLoad) {
        _selectedChannelKey = preferences.selectedChannelKey;
      }
      _channelPreferenceError = null;
    } on PaperChannelPreferencePersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperChannelPreferencesLoad,
        error,
        stackTrace,
      );
      if (!_disposed) _channelPreferenceError = error.message;
    } on Object catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperChannelPreferencesLoad,
        error,
        stackTrace,
      );
      if (!_disposed) {
        _channelPreferenceError = '论文频道设置读取失败，请稍后重试。';
      }
    } finally {
      _finishChannelLoad();
    }
  }

  void rememberPosition(String channelKey, int index) {
    _positions[channelKey] = index;
    if (_feedLoadInProgress) _positionsChangedDuringLoad.add(channelKey);
  }

  void selectTimeRange(String channelKey, PaperTimeRange range) {
    _timeRanges[channelKey] = range;
    _positions[channelKey] = 0;
    if (_feedLoadInProgress) {
      _timeRangesChangedDuringLoad.add(channelKey);
      _positionsChangedDuringLoad.add(channelKey);
    }
  }

  void replaceUserChannels(Iterable<UserPaperChannel> channels) {
    final seen = <String>{};
    _userChannels = List.unmodifiable(
      channels.where((channel) => seen.add(channel.storageKey)),
    );
    if (_channelLoadInProgress) _userChannelsChangedDuringLoad = true;
  }

  void selectChannel(String channelKey) {
    _selectedChannelKey = channelKey;
    if (_channelLoadInProgress) _selectedChannelChangedDuringLoad = true;
  }

  void queueFeedPersistence({required int primaryCategoryIndex}) {
    if (_disposed || _preferenceRepository == null) return;
    _legacyPrimaryIndex = primaryCategoryIndex.clamp(
      0,
      FixedPaperChannel.values.length - 1,
    );
    if (_feedLoadInProgress) {
      _deferredPrimaryIndex = _legacyPrimaryIndex;
      _feedPersistenceDeferred = true;
      return;
    }
    _enqueueFeedPersistence(primaryCategoryIndex: _legacyPrimaryIndex);
  }

  void _enqueueFeedPersistence({required int primaryCategoryIndex}) {
    final preferences = PaperPreferences(
      positions: _positions,
      timeRanges: {
        for (final entry in _timeRanges.entries)
          entry.key: entry.value.storageKey,
      },
      primaryCategoryIndex: primaryCategoryIndex,
    );
    _feedWriteQueue = _feedWriteQueue.then(
      (_) => _saveFeedPreferences(preferences),
    );
  }

  void queueChannelPersistence() {
    if (_disposed || _channelPreferenceRepository == null) return;
    if (_channelLoadInProgress) {
      _channelPersistenceDeferred = true;
      return;
    }
    _enqueueChannelPersistence();
  }

  void _enqueueChannelPersistence() {
    final preferences = PaperChannelPreferences(
      userChannels: _userChannels,
      selectedChannelKey: _selectedChannelKey,
    );
    _channelWriteQueue = _channelWriteQueue.then(
      (_) => _saveChannelPreferences(preferences),
    );
  }

  Future<void> _saveFeedPreferences(PaperPreferences preferences) async {
    try {
      await _preferenceRepository!.save(preferences);
      if (_disposed) return;
      _preferenceError = null;
    } on PaperPreferencePersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperFeedPreferencesSave,
        error,
        stackTrace,
      );
      if (_disposed) return;
      _preferenceError = error.message;
    } on Object catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperFeedPreferencesSave,
        error,
        stackTrace,
      );
      if (_disposed) return;
      _preferenceError = '论文浏览偏好保存失败，请稍后重试。';
    }
    onChanged?.call();
  }

  Future<void> _saveChannelPreferences(
    PaperChannelPreferences preferences,
  ) async {
    try {
      await _channelPreferenceRepository!.save(preferences);
      if (_disposed) return;
      _channelPreferenceError = null;
    } on PaperChannelPreferencePersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperChannelPreferencesSave,
        error,
        stackTrace,
      );
      if (_disposed) return;
      _channelPreferenceError = error.message;
    } on Object catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperChannelPreferencesSave,
        error,
        stackTrace,
      );
      if (_disposed) return;
      _channelPreferenceError = '论文频道设置保存失败，请稍后重试。';
    }
    onChanged?.call();
  }

  void _finishFeedLoad() {
    if (_disposed) return;
    _feedLoadInProgress = false;
    _positionsChangedDuringLoad.clear();
    _timeRangesChangedDuringLoad.clear();
    if (_feedPersistenceDeferred) {
      _feedPersistenceDeferred = false;
      final primaryCategoryIndex = _deferredPrimaryIndex ?? _legacyPrimaryIndex;
      _deferredPrimaryIndex = null;
      _enqueueFeedPersistence(
        primaryCategoryIndex: primaryCategoryIndex,
      );
    }
  }

  void _finishChannelLoad() {
    if (_disposed) return;
    _channelLoadInProgress = false;
    _userChannelsChangedDuringLoad = false;
    _selectedChannelChangedDuringLoad = false;
    if (_channelPersistenceDeferred) {
      _channelPersistenceDeferred = false;
      _enqueueChannelPersistence();
    }
  }

  Future<void> flushFeedWrites() async {
    await _feedInitialization;
    await _feedWriteQueue;
  }

  Future<void> flushChannelWrites() async {
    await _channelInitialization;
    await _channelWriteQueue;
  }

  static void _reportPersistenceFailure(
    SparkDiagnosticOperation operation,
    Object error,
    StackTrace stackTrace,
  ) {
    SparkDiagnostics.reportUnexpected(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      severity: SparkDiagnosticSeverity.warning,
    );
  }

  void reset() {
    _positions.clear();
    _timeRanges.clear();
    _userChannels = const [];
    _selectedChannelKey = null;
    _legacyPrimaryIndex = 0;
    _preferenceError = null;
    _channelPreferenceError = null;
    _deferredPrimaryIndex = null;
    _feedPersistenceDeferred = false;
    _channelPersistenceDeferred = false;
    _positionsChangedDuringLoad.clear();
    _timeRangesChangedDuringLoad.clear();
    _userChannelsChangedDuringLoad = false;
    _selectedChannelChangedDuringLoad = false;
  }

  void dispose() {
    _disposed = true;
    onChanged = null;
  }
}
