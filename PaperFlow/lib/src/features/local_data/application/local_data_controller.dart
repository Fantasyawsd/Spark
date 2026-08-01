import 'package:flutter/foundation.dart';

import '../domain/local_data_repository.dart';

typedef LocalDataMutationCallback = Future<void> Function(
  LocalDataClearTarget target,
);

class LocalDataController extends ChangeNotifier {
  LocalDataController({
    required LocalDataRepository repository,
    this.beforeClear,
    this.afterClear,
  }) : _repository = repository;

  final LocalDataRepository _repository;
  final LocalDataMutationCallback? beforeClear;
  final LocalDataMutationCallback? afterClear;

  LocalDataUsage _usage = const LocalDataUsage.empty();
  bool _loading = false;
  bool _mutating = false;
  bool _disposed = false;
  String? _error;

  LocalDataUsage get usage => _usage;
  bool get loading => _loading;
  bool get mutating => _mutating;
  String? get error => _error;

  Future<void> initialize() => refresh();

  Future<void> refresh() async {
    if (_loading || _mutating) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      _usage = await _repository.inspect();
    } on LocalDataException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<bool> clearPaperCache() => _run(
        LocalDataClearTarget.paperCache,
        _repository.clearPaperCache,
      );

  Future<bool> clearChats() => _run(
        LocalDataClearTarget.chats,
        _repository.clearChats,
      );

  Future<bool> resetAllBusinessData() => _run(
        LocalDataClearTarget.allBusinessData,
        _repository.resetAllBusinessData,
      );

  Future<bool> _run(
    LocalDataClearTarget target,
    Future<void> Function() operation,
  ) async {
    if (_mutating) return false;
    _mutating = true;
    _error = null;
    _notify();
    try {
      await beforeClear?.call(target);
      await operation();
      await afterClear?.call(target);
      _usage = await _repository.inspect();
      return true;
    } on LocalDataException catch (error) {
      _error = error.message;
      return false;
    } on Object {
      _error = '本地数据操作失败，请稍后重试。';
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
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
