import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// 内存画像仓库：预览与测试环境使用，避免真实文件 IO。
class InMemoryProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  @override
  Future<UserProfile?> read() async => _profile;

  @override
  Future<void> write(UserProfile profile) async {
    _profile = profile;
  }
}
