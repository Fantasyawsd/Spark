import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/theme/theme_controller.dart';
import 'package:spark/src/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('profile shows paper catalog source and refresh time',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            themeController: ThemeController(),
            catalogStatus: PaperCatalogStatusView(
              sourceLabel: 'arXiv 本地缓存',
              availability: PaperCatalogAvailability.offline,
              fetchedAt: null,
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-paper-source')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('论文数据源'), findsOneWidget);
    expect(find.text('arXiv 本地缓存'), findsOneWidget);
    expect(find.text('离线'), findsOneWidget);
  });

  test('catalog status formats a local refresh time', () {
    final status = PaperCatalogStatusView(
      sourceLabel: 'arXiv 远程目录',
      availability: PaperCatalogAvailability.online,
      fetchedAt: DateTime(2024, 3, 1, 9, 5),
    );

    expect(status.description, 'arXiv 远程目录 · 03-01 09:05 更新');
    expect(status.stateLabel, '在线');
  });

  testWidgets('privacy notice discloses DeepSeek data transfer',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(themeController: ThemeController()),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const ValueKey('profile-privacy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-privacy')));
    await tester.pumpAndSettle();

    expect(find.text('隐私说明'), findsOneWidget);
    expect(find.textContaining('发送到 DeepSeek 官方接口'), findsOneWidget);
    expect(find.textContaining('系统安全存储'), findsOneWidget);
  });

  test('seed catalog is reported as local instead of online', () {
    const status = PaperCatalogStatusView(
      sourceLabel: '内置论文',
      availability: PaperCatalogAvailability.local,
    );

    expect(status.stateLabel, '本地');
  });
}
