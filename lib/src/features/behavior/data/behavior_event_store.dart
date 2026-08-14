import '../../../core/storage/local_json_store.dart';
import '../domain/behavior_event.dart';
import '../domain/behavior_event_repository.dart';

/// 设备本地行为事件存储：保留期滚动清理 + 条目上限 + 损坏隔离沿用 LocalJsonStore。
class BehaviorEventStore implements BehaviorEventRepository {
  BehaviorEventStore({
    required LocalJsonStore store,
    DateTime Function()? clock,
    this.retention = const Duration(days: 90),
    this.maxEntries = 10000,
  })  : _store = store,
        _clock = clock ?? DateTime.now;

  static const String _schema = 'behavior-events.v1';

  final LocalJsonStore _store;
  final DateTime Function() _clock;
  final Duration retention;
  final int maxEntries;

  @override
  Future<void> append(BehaviorEvent event) async {
    await _store.transaction((transaction) async {
      final payload = await transaction.read();
      final events = _decode(payload);
      events.add(event.toJson());
      final cutoff = _clock().toUtc().subtract(retention);
      events.removeWhere((item) {
        final occurredAt = DateTime.tryParse(item['occurred_at'] as String? ?? '');
        return occurredAt == null || occurredAt.toUtc().isBefore(cutoff);
      });
      if (events.length > maxEntries) {
        events.removeRange(0, events.length - maxEntries);
      }
      await transaction.write({'schema': _schema, 'events': events});
    });
  }

  @override
  Future<List<BehaviorEvent>> events() async {
    final payload = await _store.read();
    final cutoff = _clock().toUtc().subtract(retention);
    return _decode(payload)
        .map(_eventFromJson)
        .where((event) => !event.occurredAt.toUtc().isBefore(cutoff))
        .toList(growable: false);
  }

  @override
  Future<int> count() async => (await events()).length;

  @override
  Future<void> clear() => _store.clear();

  List<Map<String, dynamic>> _decode(Object? payload) {
    if (payload is! Map) return [];
    final schema = payload['schema'];
    if (schema != _schema) return [];
    final rawEvents = payload['events'];
    if (rawEvents is! List) return [];
    return rawEvents.whereType<Map<String, dynamic>>().toList();
  }

  static BehaviorEvent _eventFromJson(Map<String, dynamic> json) {
    return BehaviorEvent.fromJson(json);
  }
}
