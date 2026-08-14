import '../domain/behavior_event_repository.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';
import 'profile_aggregator.dart';

/// 行为画像服务：读取本地事件 → 聚合 → 持久化画像。
class BehaviorProfileService {
  BehaviorProfileService({
    required BehaviorEventRepository events,
    required ProfileRepository profiles,
    ProfileAggregator? aggregator,
    required PaperProfileMetadata Function(String paperId) resolveMetadata,
  })  : _events = events,
        _profiles = profiles,
        _aggregator = aggregator ?? ProfileAggregator(),
        _resolveMetadata = resolveMetadata;

  final BehaviorEventRepository _events;
  final ProfileRepository _profiles;
  final ProfileAggregator _aggregator;
  final PaperProfileMetadata Function(String paperId) _resolveMetadata;

  Future<UserProfile?> refresh() async {
    final events = await _events.events();
    final profile = _aggregator.aggregate(
      events,
      resolveMetadata: _resolveMetadata,
    );
    await _profiles.write(profile);
    return profile;
  }

  Future<UserProfile?> read() => _profiles.read();
}
