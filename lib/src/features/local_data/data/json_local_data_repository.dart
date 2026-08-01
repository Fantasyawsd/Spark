import '../../../core/storage/local_json_store.dart';
import '../domain/local_data_repository.dart';

class JsonLocalDataRepository implements LocalDataRepository {
  JsonLocalDataRepository({
    required Iterable<LocalJsonStore> paperCacheStores,
    required Iterable<LocalJsonStore> chatStores,
    required Iterable<LocalJsonStore> businessDataStores,
  })  : _paperCacheStores = List.unmodifiable(paperCacheStores),
        _chatStores = List.unmodifiable(chatStores),
        _businessDataStores = List.unmodifiable(businessDataStores);

  final List<LocalJsonStore> _paperCacheStores;
  final List<LocalJsonStore> _chatStores;
  final List<LocalJsonStore> _businessDataStores;

  @override
  Future<LocalDataUsage> inspect() async {
    try {
      final sizes = await Future.wait([
        _sumSizes(_paperCacheStores),
        _sumSizes(_chatStores),
        _sumSizes(_businessDataStores),
      ]);
      return LocalDataUsage(
        paperCacheBytes: sizes[0],
        chatBytes: sizes[1],
        businessDataBytes: sizes[2],
      );
    } catch (error) {
      throw LocalDataException('无法统计本地数据占用。', error);
    }
  }

  @override
  Future<void> clearPaperCache() => _clear(
        _paperCacheStores,
        errorMessage: '无法清理论文缓存。',
      );

  @override
  Future<void> clearChats() => _clear(
        _chatStores,
        errorMessage: '无法清理 ChatPaper 对话。',
      );

  @override
  Future<void> resetAllBusinessData() => _clear(
        {
          ..._paperCacheStores,
          ..._chatStores,
          ..._businessDataStores,
        },
        errorMessage: '无法重置本地数据。',
      );

  static Future<int> _sumSizes(Iterable<LocalJsonStore> stores) async {
    final sizes = await Future.wait<int>(
      stores.map((store) => store.sizeInBytes()),
    );
    return sizes.fold<int>(0, (total, size) => total + size);
  }

  static Future<void> _clear(
    Iterable<LocalJsonStore> stores, {
    required String errorMessage,
  }) async {
    try {
      await Future.wait(stores.map((store) => store.clear()));
    } catch (error) {
      throw LocalDataException(errorMessage, error);
    }
  }
}
