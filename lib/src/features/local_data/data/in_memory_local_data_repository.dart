import '../domain/local_data_repository.dart';

class InMemoryLocalDataRepository implements LocalDataRepository {
  InMemoryLocalDataRepository([this._usage = const LocalDataUsage.empty()]);

  LocalDataUsage _usage;

  @override
  Future<LocalDataUsage> inspect() async => _usage;

  @override
  Future<void> clearPaperCache() async {
    _usage = LocalDataUsage(
      paperCacheBytes: 0,
      chatBytes: _usage.chatBytes,
      businessDataBytes: _usage.businessDataBytes,
    );
  }

  @override
  Future<void> clearChats() async {
    _usage = LocalDataUsage(
      paperCacheBytes: _usage.paperCacheBytes,
      chatBytes: 0,
      businessDataBytes: _usage.businessDataBytes,
    );
  }

  @override
  Future<void> resetAllBusinessData() async {
    _usage = const LocalDataUsage.empty();
  }
}
