import '../../../core/storage/local_json_store.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// 用户画像本地持久化实现。
class FileProfileStore implements ProfileRepository {
  FileProfileStore({required LocalJsonStore store}) : _store = store;

  final LocalJsonStore _store;

  @override
  Future<UserProfile?> read() async {
    final payload = await _store.read();
    if (payload is! Map) return null;
    try {
      return UserProfile.fromJson(Map<String, dynamic>.from(payload));
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(UserProfile profile) {
    return _store.write(profile.toJson());
  }
}
