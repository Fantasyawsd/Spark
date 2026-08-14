import 'behavior_event.dart';

/// 行为事件存储端口（本地保留期与上限由实现保证）。
abstract interface class BehaviorEventRepository {
  Future<void> append(BehaviorEvent event);

  Future<List<BehaviorEvent>> events();

  Future<int> count();

  Future<void> clear();
}
