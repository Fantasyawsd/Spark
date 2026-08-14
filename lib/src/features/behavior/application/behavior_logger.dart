import '../domain/behavior_consent_repository.dart';
import '../domain/behavior_event.dart';
import '../domain/behavior_event_repository.dart';
import '../domain/behavior_log_port.dart';

/// 行为记录器：同意开关门控；关闭时丢弃事件。事件仅留在设备本地。
class BehaviorLogger implements BehaviorLogPort {
  BehaviorLogger({
    required BehaviorConsentRepository consent,
    required BehaviorEventRepository events,
    DateTime Function()? clock,
  })  : _consent = consent,
        _events = events,
        _clock = clock ?? DateTime.now;

  final BehaviorConsentRepository _consent;
  final BehaviorEventRepository _events;
  final DateTime Function() _clock;

  @override
  Future<void> logPaperOpened(
    String paperId, {
    Map<String, String> context = const {},
  }) =>
      _log(BehaviorEventType.paperOpened, paperId, context);

  @override
  Future<void> logPaperLiked(
    String paperId, {
    Map<String, String> context = const {},
  }) =>
      _log(BehaviorEventType.paperLiked, paperId, context);

  @override
  Future<void> logPaperSaved(
    String paperId, {
    Map<String, String> context = const {},
  }) =>
      _log(BehaviorEventType.paperSaved, paperId, context);

  Future<void> _log(
    BehaviorEventType type,
    String paperId,
    Map<String, String> context,
  ) async {
    if (!await _consent.isEnabled()) return;
    await _events.append(
      BehaviorEvent(
        type: type,
        paperId: paperId,
        occurredAt: _clock().toUtc(),
        context: context,
      ),
    );
  }

  Future<void> clearEvents() => _events.clear();
}
