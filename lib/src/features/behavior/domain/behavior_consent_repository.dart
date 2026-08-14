/// 行为采集同意开关端口。
abstract interface class BehaviorConsentRepository {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool value);
}
