import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/core/theme/in_memory_theme_preference_repository.dart';
import 'package:spark/src/core/theme/spark_design_tokens.dart';
import 'package:spark/src/features/profile/presentation/profile_theme_sheet.dart';

void main() {
  test('material theme maps the selected accent to semantic colors', () {
    final theme = SparkTheme.light(SparkThemeColor.blue);

    final palette = SparkPalette.light(SparkThemeColor.blue);
    expect(theme.colorScheme.primary, SparkThemeColor.blue.value);
    expect(theme.colorScheme.primaryContainer, SparkThemeColor.blue.soft);
    expect(theme.colorScheme.surface, palette.card);
    expect(theme.colorScheme.onSurface, palette.ink);
    expect(theme.colorScheme.error, palette.danger);
    expect(theme.inputDecorationTheme.fillColor, palette.surfaceMuted);
    expect(theme.scaffoldBackgroundColor, palette.canvas);
  });

  test('theme accents keep readable contrast with white content', () {
    for (final color in SparkThemeColor.values) {
      final contrast = 1.05 / (color.value.computeLuminance() + 0.05);
      // iOS 系统色作按钮底色配白字时 Apple 自身即 ~4.0（systemBlue
      // #007AFF = 4.02），故门限取 WCAG 图形组件级 3.0，不用正文级 4.5。
      expect(
        contrast,
        greaterThanOrEqualTo(3.0),
        reason: '${color.label} must support white button content',
      );
    }
  });

  test('dark palette keeps accent text readable on the dark card', () {
    for (final color in SparkThemeColor.values) {
      final palette = SparkPalette.dark(color);
      final contrast = (palette.primary.computeLuminance() + 0.05) /
          (palette.card.computeLuminance() + 0.05);
      expect(
        contrast,
        greaterThanOrEqualTo(4.5),
        reason: '${color.label} must stay readable as text on the dark card',
      );
    }
  });

  testWidgets('theme sheet shows all palettes and updates the accent', (
    tester,
  ) async {
    final controller = ThemeController();
    await controller.configure(InMemoryThemePreferenceRepository());
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: SparkTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showProfileThemeSheet(context, controller: controller),
                child: const Text('打开主题'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开主题'));
    await tester.pumpAndSettle();

    expect(find.text('主题与配色'), findsOneWidget);
    for (final color in SparkThemeColor.values) {
      expect(find.byKey(ValueKey('spark-theme-${color.name}')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('spark-theme-green')));
    await tester.pumpAndSettle();

    expect(controller.color, SparkThemeColor.green);
  });

  testWidgets('theme sheet switches the appearance mode', (tester) async {
    final controller = ThemeController();
    await controller.configure(InMemoryThemePreferenceRepository());
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: SparkTheme.light(),
        darkTheme: SparkTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showProfileThemeSheet(context, controller: controller),
                child: const Text('打开主题'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开主题'));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsOneWidget);
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(controller.mode, AppThemeMode.dark);
  });

  test('iOS baseline tokens stay locked', () {
    final light = SparkTheme.light();
    final lightPalette = light.extension<SparkPalette>()!;
    expect(lightPalette.canvas, const Color(0xFFF2F2F7));
    expect(light.scaffoldBackgroundColor, const Color(0xFFF2F2F7));
    expect(light.appBarTheme.centerTitle, isTrue);
    expect(
      light.appBarTheme.titleTextStyle?.fontWeight,
      FontWeight.w600,
    );
    expect(light.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    expect(light.textTheme.titleLarge?.fontWeight, FontWeight.w600);

    final cardShape = light.cardTheme.shape as RoundedRectangleBorder?;
    expect(cardShape?.side, BorderSide.none);

    // analyzer 与测试编译器对 trackColor 可空性视图不一致，经 Object?
    // 显式收窄，两种工具均无告警。
    final Object? trackProp = light.switchTheme.trackColor;
    final trackOn = (trackProp as WidgetStateProperty<Color?>?)?.resolve(
      const {WidgetState.selected},
    );
    expect(trackOn, const Color(0xFF34C759));

    final dark = SparkTheme.dark();
    final darkPalette = dark.extension<SparkPalette>()!;
    expect(darkPalette.canvas, const Color(0xFF000000));
    expect(darkPalette.card, const Color(0xFF1C1C1E));

    expect(SparkDesignTokens.radiusCard, 16.0);
    expect(SparkDesignTokens.radiusOverlay, 20.0);
    expect(SparkDesignTokens.radiusDialog, 14.0);
  });

  test('dark theme carries the dark palette', () {
    final theme = SparkTheme.dark();

    final palette = theme.extension<SparkPalette>()!;
    expect(palette.canvas, SparkPalette.dark().canvas);
    expect(theme.scaffoldBackgroundColor, palette.canvas);
    expect(theme.brightness, Brightness.dark);
  });

  testWidgets('dark mode paints the scaffold with the dark canvas',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SparkTheme.light(),
        darkTheme: SparkTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      SparkPalette.dark(SparkThemeColor.pink).canvas,
    );
  });

  testWidgets('SparkApp rebuilds from its injected theme controller',
      (tester) async {
    final controller = ThemeController();
    final repository = InMemoryThemePreferenceRepository();
    await controller.configure(repository);

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(
          themeController: controller,
          themePreferenceRepository: repository,
        ),
      ),
    );
    await tester.pump();
    BuildContext shellContext = tester.element(find.byType(SparkShell));
    expect(
      Theme.of(shellContext).colorScheme.primary,
      SparkThemeColor.pink.value,
    );

    controller.setColor(SparkThemeColor.blue);
    controller.setMode(AppThemeMode.dark);
    await tester.pumpAndSettle();
    shellContext = tester.element(find.byType(SparkShell));

    expect(
      Theme.of(shellContext).colorScheme.primary,
      SparkThemeColor.blue.darkValue,
    );
    expect(Theme.of(shellContext).brightness, Brightness.dark);
  });
}
