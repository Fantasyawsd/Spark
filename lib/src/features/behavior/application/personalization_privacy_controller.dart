import 'package:flutter/foundation.dart';

import '../domain/behavior_consent_repository.dart';
import '../domain/behavior_event_repository.dart';
import '../domain/profile_repository.dart';

/// 个性化隐私开关控制器：聚合行为采集同意状态与本地行为数据清理，
/// 供「我的」页隐私区展示与操作。事件与画像仅保存在设备本地。
class PersonalizationPrivacyController extends ChangeNotifier {
  PersonalizationPrivacyController({
    required BehaviorConsentRepository consent,
    required BehaviorEventRepository events,
    required ProfileRepository profiles,
  })  : _consent = consent,
        _events = events,
        _profiles = profiles {
    _load();
  }

  final BehaviorConsentRepository _consent;
  final BehaviorEventRepository _events;
  final ProfileRepository _profiles;

  bool? _personalized;

  /// 个性化推荐开关状态；null 表示仍在加载，UI 应禁用开关。
  bool? get personalized => _personalized;

  Future<void> _load() async {
    final enabled = await _consent.isEnabled();
    _personalized = enabled;
    notifyListeners();
  }

  Future<void> setPersonalized(bool value) async {
    await _consent.setEnabled(value);
    _personalized = value;
    notifyListeners();
  }

  /// 清除设备本地的行为事件与偏好画像，不影响同意开关本身。
  Future<void> clearBehaviorData() async {
    await _events.clear();
    await _profiles.clear();
    notifyListeners();
  }
}
