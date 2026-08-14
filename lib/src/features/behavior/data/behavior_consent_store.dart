import '../../../core/storage/local_json_store.dart';
import '../domain/behavior_consent_repository.dart';

/// 行为采集同意开关（默认开启）；关闭即停止采集，用户可随时清除已采事件。
class BehaviorConsentStore implements BehaviorConsentRepository {
  BehaviorConsentStore({required LocalJsonStore store}) : _store = store;

  static const String _schema = 'behavior-consent.v1';

  final LocalJsonStore _store;

  @override
  Future<bool> isEnabled() async {
    final payload = await _store.read();
    if (payload is! Map) return true;
    if (payload['schema'] != _schema) return true;
    final enabled = payload['enabled'];
    return enabled is bool ? enabled : true;
  }

  @override
  Future<void> setEnabled(bool value) {
    return _store.write({'schema': _schema, 'enabled': value});
  }
}
