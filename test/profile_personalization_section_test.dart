import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/theme/spark_theme.dart';
import 'package:spark/src/core/theme/theme_controller.dart';
import 'package:spark/src/features/behavior/behavior.dart';
import 'package:spark/src/features/behavior/data/in_memory_profile_repository.dart';
import 'package:spark/src/features/profile/presentation/profile_settings_section.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    PersonalizationPrivacyController? controller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SparkTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSettingsSection(
              catalogSourceDescription: null,
              catalogStateLabel: null,
              catalogOffline: false,
              fallbackLocalDataDescription: '收藏 0 · 稍后阅读 0 · 阅读历史 0',
              themeController: ThemeController(),
              personalizationController: controller,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> waitForLoad(
    WidgetTester tester,
    PersonalizationPrivacyController controller,
  ) async {
    for (var attempt = 0;
        attempt < 20 && controller.personalized == null;
        attempt++) {
      await tester.pump();
    }
  }

  testWidgets('个性化开关存在且切换写入同意状态', (tester) async {
    final consent = _InMemoryConsentRepository();
    final controller = PersonalizationPrivacyController(
      consent: consent,
      events: _InMemoryEventRepository(),
      profiles: InMemoryProfileRepository(),
    );

    await pumpSection(tester, controller: controller);
    await waitForLoad(tester, controller);
    await tester.pump();

    final switchFinder = find.byKey(
      const ValueKey('profile-personalization-switch'),
    );
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pump();

    expect(await consent.isEnabled(), isFalse);
    expect(controller.personalized, isFalse);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
  });

  testWidgets('清除行为数据需确认，确认后清除并提示', (tester) async {
    final events = _InMemoryEventRepository();
    final profiles = InMemoryProfileRepository();
    final controller = PersonalizationPrivacyController(
      consent: _InMemoryConsentRepository(),
      events: events,
      profiles: profiles,
    );
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

    await pumpSection(tester, controller: controller);
    await waitForLoad(tester, controller);

    await tester.tap(find.byKey(const ValueKey('profile-clear-behavior-data')));
    await tester.pumpAndSettle();

    final confirmFinder = find.byKey(
      const ValueKey('profile-clear-behavior-confirm'),
    );
    expect(confirmFinder, findsOneWidget);

    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    expect(await events.count(), 0);
    expect(await profiles.read(), isNull);
    expect(find.text('已清除行为数据'), findsOneWidget);
  });

  testWidgets('取消清除对话框时不清理数据', (tester) async {
    final events = _InMemoryEventRepository();
    final controller = PersonalizationPrivacyController(
      consent: _InMemoryConsentRepository(),
      events: events,
      profiles: InMemoryProfileRepository(),
    );
    await events.append(
      BehaviorEvent(
        type: BehaviorEventType.paperLiked,
        paperId: 'paper-2',
        occurredAt: DateTime.utc(2026, 8, 14),
      ),
    );

    await pumpSection(tester, controller: controller);
    await waitForLoad(tester, controller);

    await tester.tap(find.byKey(const ValueKey('profile-clear-behavior-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await events.count(), 1);
    expect(find.text('已清除行为数据'), findsNothing);
  });

  testWidgets('未注入控制器时隐藏个性化区', (tester) async {
    await pumpSection(tester);

    expect(
      find.byKey(const ValueKey('profile-personalization-switch')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('profile-clear-behavior-data')),
      findsNothing,
    );
    expect(find.text('个性化推荐'), findsNothing);
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
