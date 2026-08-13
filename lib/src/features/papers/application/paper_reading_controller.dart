import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/paper_reading_repository.dart';

class PaperReadingController extends ChangeNotifier {
  PaperReadingController({PaperReadingRepository? repository})
      : _repository = repository,
        _initialized = repository == null;

  static const historyLimit = 100;

  final PaperReadingRepository? _repository;
  final Set<String> _readPaperIds = {};
  final Set<String> _readLaterPaperIds = {};
  final List<String> _historyPaperIds = [];
  final Map<String, int> _tabIndices = {};
  final Map<String, double> _abstractScrollOffsets = {};
  final Map<String, int> _dwellMilliseconds = {};
  final List<_ReadingMutation> _pendingMutations = [];
  Future<void> _writeQueue = Future.value();
  Future<void>? _initialization;
  String? _persistenceError;
  int _writeRevision = 0;
  bool _disposed = false;
  bool _initialized;

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

  Future<void> initialize() {
    if (_disposed || _initialized) return Future.value();
    final existing = _initialization;
    if (existing != null) return existing;
    final repository = _repository;
    if (repository == null) {
      _pendingMutations.clear();
      _initialized = true;
      _notify();
      return Future.value();
    }
    late final Future<void> operation;
    operation = _initialize(repository).whenComplete(() {
      if (identical(_initialization, operation)) _initialization = null;
    });
    _initialization = operation;
    return operation;
  }

  Future<void> _initialize(PaperReadingRepository repository) async {
    try {
      final snapshot = await repository.load();
      if (_disposed) return;
      final pendingMutations = List<_ReadingMutation>.of(_pendingMutations);
      _pendingMutations.clear();
      _restore(snapshot);
      for (final mutation in pendingMutations) {
        _applyMutation(mutation);
      }
      _initialized = true;
      _persistenceError = null;
      _notify();
      if (pendingMutations.isNotEmpty) _queuePersistence();
    } on PaperReadingPersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperReadingLoad,
        error,
        stackTrace,
      );
      _finishFailedInitialization(error.message);
    } on Object catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperReadingLoad,
        error,
        stackTrace,
      );
      _finishFailedInitialization('阅读记录读取失败，请稍后重试。');
    }
  }

  void _finishFailedInitialization(String message) {
    if (_disposed) return;
    final hasPendingMutations = _pendingMutations.isNotEmpty;
    _pendingMutations.clear();
    _initialized = true;
    _persistenceError = message;
    _notify();
    if (hasPendingMutations) _queuePersistence();
  }

  void recordOpened(String paperId) {
    if (paperId.isEmpty) return;
    _mutate(_ReadingMutation.opened(paperId));
  }

  void toggleRead(String paperId) {
    _mutate(_ReadingMutation.toggleRead(paperId));
  }

  void toggleReadLater(String paperId) {
    _mutate(_ReadingMutation.toggleReadLater(paperId));
  }

  void selectTab(String paperId, int index) {
    if (index < 0 || _tabIndices[paperId] == index) return;
    _mutate(_ReadingMutation.selectTab(paperId, index));
  }

  void saveAbstractScrollOffset(String paperId, double offset) {
    final normalized =
        offset.isFinite ? offset.clamp(0, double.infinity).toDouble() : 0.0;
    if ((_abstractScrollOffsets[paperId] ?? 0) == normalized) return;
    _mutate(_ReadingMutation.scrollOffset(paperId, normalized));
  }

  void addDwellTime(String paperId, Duration duration) {
    if (duration <= Duration.zero) return;
    _mutate(
      _ReadingMutation.dwellTime(paperId, duration.inMilliseconds),
      notify: false,
    );
  }

  void _mutate(_ReadingMutation mutation, {bool notify = true}) {
    if (_disposed) return;
    _applyMutation(mutation);
    if (_initialized) {
      _persistenceError = null;
      _queuePersistence();
    } else {
      _pendingMutations.add(mutation);
      unawaited(initialize());
    }
    if (notify) _notify();
  }

  void _applyMutation(_ReadingMutation mutation) {
    switch (mutation.type) {
      case _ReadingMutationType.opened:
        _readPaperIds.add(mutation.paperId);
        _historyPaperIds
          ..remove(mutation.paperId)
          ..insert(0, mutation.paperId);
        if (_historyPaperIds.length > historyLimit) {
          _historyPaperIds.removeRange(historyLimit, _historyPaperIds.length);
        }
      case _ReadingMutationType.toggleRead:
        if (!_readPaperIds.remove(mutation.paperId)) {
          _readPaperIds.add(mutation.paperId);
        }
      case _ReadingMutationType.toggleReadLater:
        if (!_readLaterPaperIds.remove(mutation.paperId)) {
          _readLaterPaperIds.add(mutation.paperId);
        }
      case _ReadingMutationType.selectTab:
        _tabIndices[mutation.paperId] = mutation.intValue!;
      case _ReadingMutationType.scrollOffset:
        _abstractScrollOffsets[mutation.paperId] = mutation.doubleValue!;
      case _ReadingMutationType.dwellTime:
        _dwellMilliseconds.update(
          mutation.paperId,
          (value) => value + mutation.intValue!,
          ifAbsent: () => mutation.intValue!,
        );
    }
  }

  Future<void> flushPendingWrites() async {
    await _initialization;
    await _writeQueue;
  }

  Future<void> reload() async {
    await flushPendingWrites();
    if (_disposed) return;
    _initialized = false;
    _pendingMutations.clear();
    _restore(PaperReadingSnapshot());
    await initialize();
  }

  void _queuePersistence() {
    final repository = _repository;
    if (repository == null) return;
    final snapshot = _snapshot();
    final revision = ++_writeRevision;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(snapshot);
        if (!_disposed && revision == _writeRevision) {
          _persistenceError = null;
        }
      } on PaperReadingPersistenceException catch (error, stackTrace) {
        _reportPersistenceFailure(
          SparkDiagnosticOperation.paperReadingSave,
          error,
          stackTrace,
        );
        if (!_disposed && revision == _writeRevision) {
          _persistenceError = error.message;
        }
      } on Object catch (error, stackTrace) {
        _reportPersistenceFailure(
          SparkDiagnosticOperation.paperReadingSave,
          error,
          stackTrace,
        );
        if (!_disposed && revision == _writeRevision) {
          _persistenceError = '阅读记录保存失败，请稍后重试。';
        }
      }
      _notify();
    });
  }

  void _restore(PaperReadingSnapshot snapshot) {
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
  }

  PaperReadingSnapshot _snapshot() => PaperReadingSnapshot(
        readPaperIds: _readPaperIds,
        readLaterPaperIds: _readLaterPaperIds,
        historyPaperIds: _historyPaperIds,
        tabIndices: _tabIndices,
        abstractScrollOffsets: _abstractScrollOffsets,
        dwellMilliseconds: _dwellMilliseconds,
      );

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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

enum _ReadingMutationType {
  opened,
  toggleRead,
  toggleReadLater,
  selectTab,
  scrollOffset,
  dwellTime,
}

class _ReadingMutation {
  const _ReadingMutation._(
    this.type,
    this.paperId, {
    this.intValue,
    this.doubleValue,
  });

  const _ReadingMutation.opened(String paperId)
      : this._(_ReadingMutationType.opened, paperId);

  const _ReadingMutation.toggleRead(String paperId)
      : this._(_ReadingMutationType.toggleRead, paperId);

  const _ReadingMutation.toggleReadLater(String paperId)
      : this._(_ReadingMutationType.toggleReadLater, paperId);

  const _ReadingMutation.selectTab(String paperId, int index)
      : this._(_ReadingMutationType.selectTab, paperId, intValue: index);

  const _ReadingMutation.scrollOffset(String paperId, double offset)
      : this._(
          _ReadingMutationType.scrollOffset,
          paperId,
          doubleValue: offset,
        );

  const _ReadingMutation.dwellTime(String paperId, int milliseconds)
      : this._(
          _ReadingMutationType.dwellTime,
          paperId,
          intValue: milliseconds,
        );

  final _ReadingMutationType type;
  final String paperId;
  final int? intValue;
  final double? doubleValue;
}
