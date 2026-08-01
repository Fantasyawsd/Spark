import 'package:flutter/foundation.dart';

import '../domain/paper_reading_repository.dart';

class PaperReadingController extends ChangeNotifier {
  PaperReadingController({PaperReadingRepository? repository})
      : _repository = repository;

  static const historyLimit = 100;

  final PaperReadingRepository? _repository;
  final Set<String> _readPaperIds = {};
  final Set<String> _readLaterPaperIds = {};
  final List<String> _historyPaperIds = [];
  final Map<String, int> _tabIndices = {};
  final Map<String, double> _abstractScrollOffsets = {};
  final Map<String, int> _dwellMilliseconds = {};
  Future<void> _writeQueue = Future.value();
  String? _persistenceError;
  bool _disposed = false;
  bool _initialized = false;

  Set<String> get readPaperIds => Set.unmodifiable(_readPaperIds);
  Set<String> get readLaterPaperIds => Set.unmodifiable(_readLaterPaperIds);
  List<String> get historyPaperIds => List.unmodifiable(_historyPaperIds);
  String? get persistenceError => _persistenceError;
  bool get initialized => _initialized;

  bool isRead(String paperId) => _readPaperIds.contains(paperId);
  bool isReadLater(String paperId) => _readLaterPaperIds.contains(paperId);
  int tabIndex(String paperId) => _tabIndices[paperId] ?? 0;
  double abstractScrollOffset(String paperId) =>
      _abstractScrollOffsets[paperId] ?? 0;
  Duration dwellTime(String paperId) =>
      Duration(milliseconds: _dwellMilliseconds[paperId] ?? 0);

  Future<void> initialize() async {
    final repository = _repository;
    if (repository == null) {
      _initialized = true;
      _notify();
      return;
    }
    try {
      final snapshot = await repository.load();
      if (_disposed) return;
      _readPaperIds
        ..clear()
        ..addAll(snapshot.readPaperIds);
      _readLaterPaperIds
        ..clear()
        ..addAll(snapshot.readLaterPaperIds);
      _historyPaperIds
        ..clear()
        ..addAll(snapshot.historyPaperIds.take(historyLimit));
      _tabIndices
        ..clear()
        ..addAll(snapshot.tabIndices);
      _abstractScrollOffsets
        ..clear()
        ..addAll(snapshot.abstractScrollOffsets);
      _dwellMilliseconds
        ..clear()
        ..addAll(snapshot.dwellMilliseconds);
      _persistenceError = null;
    } on PaperReadingPersistenceException catch (error) {
      if (!_disposed) _persistenceError = error.message;
    }
    _initialized = true;
    _notify();
  }

  void recordOpened(String paperId) {
    if (paperId.isEmpty) return;
    _readPaperIds.add(paperId);
    _historyPaperIds
      ..remove(paperId)
      ..insert(0, paperId);
    if (_historyPaperIds.length > historyLimit) {
      _historyPaperIds.removeRange(historyLimit, _historyPaperIds.length);
    }
    _commit();
  }

  void toggleRead(String paperId) {
    if (!_readPaperIds.remove(paperId)) _readPaperIds.add(paperId);
    _commit();
  }

  void toggleReadLater(String paperId) {
    if (!_readLaterPaperIds.remove(paperId)) {
      _readLaterPaperIds.add(paperId);
    }
    _commit();
  }

  void selectTab(String paperId, int index) {
    if (index < 0 || _tabIndices[paperId] == index) return;
    _tabIndices[paperId] = index;
    _commit();
  }

  void saveAbstractScrollOffset(String paperId, double offset) {
    final normalized =
        offset.isFinite ? offset.clamp(0, double.infinity).toDouble() : 0.0;
    if ((_abstractScrollOffsets[paperId] ?? 0) == normalized) return;
    _abstractScrollOffsets[paperId] = normalized;
    _commit();
  }

  void addDwellTime(String paperId, Duration duration) {
    if (duration <= Duration.zero) return;
    _dwellMilliseconds.update(
      paperId,
      (value) => value + duration.inMilliseconds,
      ifAbsent: () => duration.inMilliseconds,
    );
    // Dwell time is telemetry and has no immediate visual representation.
    _queuePersistence();
  }

  Future<void> flushPendingWrites() => _writeQueue;

  Future<void> reload() async {
    await flushPendingWrites();
    await initialize();
  }

  void _commit() {
    _notify();
    _queuePersistence();
  }

  void _queuePersistence() {
    final repository = _repository;
    if (repository == null) return;
    final snapshot = _snapshot();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(snapshot);
        _persistenceError = null;
      } on PaperReadingPersistenceException catch (error) {
        _persistenceError = error.message;
      }
      _notify();
    });
  }

  PaperReadingSnapshot _snapshot() => PaperReadingSnapshot(
        readPaperIds: _readPaperIds,
        readLaterPaperIds: _readLaterPaperIds,
        historyPaperIds: _historyPaperIds,
        tabIndices: _tabIndices,
        abstractScrollOffsets: _abstractScrollOffsets,
        dwellMilliseconds: _dwellMilliseconds,
      );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
