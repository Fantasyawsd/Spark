class LocalDataUsage {
  const LocalDataUsage({
    required this.paperCacheBytes,
    required this.chatBytes,
    required this.businessDataBytes,
  });

  const LocalDataUsage.empty()
      : paperCacheBytes = 0,
        chatBytes = 0,
        businessDataBytes = 0;

  final int paperCacheBytes;
  final int chatBytes;
  final int businessDataBytes;

  int get totalBytes => paperCacheBytes + chatBytes + businessDataBytes;
}

enum LocalDataClearTarget { paperCache, chats, allBusinessData }

abstract interface class LocalDataRepository {
  Future<LocalDataUsage> inspect();

  Future<void> clearPaperCache();

  Future<void> clearChats();

  Future<void> resetAllBusinessData();
}

class LocalDataException implements Exception {
  const LocalDataException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
