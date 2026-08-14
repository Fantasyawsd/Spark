import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/behavior/behavior.dart';
import 'package:spark/src/features/behavior/data/in_memory_profile_repository.dart';

void main() {
  late _InMemoryConsentRepository consent;
  late _InMemoryEventRepository events;
  late InMemoryProfileRepository profiles;
  late PersonalizationPrivacyController controller;

  setUp(() {
    consent = _InMemoryConsentRepository();
    events = _InMemoryEventRepository();
    profiles = InMemoryProfileRepository();
    controller = PersonalizationPrivacyController(
      consent: consent,
      events: events,
      profiles: profiles,
    );
  });

  Future<void> waitForLoad() async {
    while (controller.personalized == null) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('初始化加载同意状态，默认开启个性化', () async {
    await waitForLoad();
    expect(controller.personalized, isTrue);
  });

  test('setPersonalized(false) 写入同意仓库并更新状态', () async {
    await waitForLoad();
    await controller.setPersonalized(false);
    expect(await consent.isEnabled(), isFalse);
    expect(controller.personalized, isFalse);

    await controller.setPersonalized(true);
    expect(await consent.isEnabled(), isTrue);
    expect(controller.personalized, isTrue);
  });

  test('clearBehaviorData 清除行为事件与偏好画像', () async {
    await events.append(
      BehaviorEvent(
        type: BehaviorEventType.paperOpened,
        paperId: 'paper-1',
        occurredAt: DateTime.utc(2026, 8, 14),
      ),
    );
    await profiles.write(
      UserProfile.empty(updatedAt: DateTime.utc(2026, 8, 14)),
    );
    expect(await events.count(), 1);
    expect(await profiles.read(), isNotNull);

    await controller.clearBehaviorData();

    expect(await events.count(), 0);
    expect(await profiles.read(), isNull);
  });
}

class _InMemoryConsentRepository implements BehaviorConsentRepository {
  bool enabled = true;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
  }
}

class _InMemoryEventRepository implements BehaviorEventRepository {
  final List<BehaviorEvent> items = [];

  @override
  Future<void> append(BehaviorEvent event) async {
    items.add(event);
  }

  @override
  Future<List<BehaviorEvent>> events() async => List.unmodifiable(items);

  @override
  Future<int> count() async => items.length;

  @override
  Future<void> clear() async {
    items.clear();
  }
}
