import 'user_profile.dart';

/// 用户画像本地持久化端口。
abstract interface class ProfileRepository {
  Future<UserProfile?> read();

  Future<void> write(UserProfile profile);
}
