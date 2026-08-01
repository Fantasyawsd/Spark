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
    var succeeded = true;
    try {
      await beforeClear?.call(target);
      await operation();
    } on LocalDataException catch (error) {
      _error = error.message;
      succeeded = false;
    } on Object {
      _error = '本地数据操作失败，请稍后重试。';
      succeeded = false;
    } finally {
      try {
        await afterClear?.call(target);
      } on Object {
        _error ??= '本地数据已变更，但页面状态刷新失败，请重启应用。';
        succeeded = false;
      }
      try {
        _usage = await _repository.inspect();
      } on LocalDataException catch (error) {
        _error ??= error.message;
        succeeded = false;
      } on Object {
        _error ??= '无法重新统计本地数据占用。';
        succeeded = false;
      }
      _mutating = false;
      _notify();
    }
    return succeeded;
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
