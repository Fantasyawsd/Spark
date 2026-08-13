import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/core/theme/in_memory_theme_preference_repository.dart';
import 'package:spark/src/features/profile/presentation/profile_theme_sheet.dart';

void main() {
  setUp(() async {
    ThemeController.instance.debugResetForTesting();
    await ThemeController.instance.configure(
      InMemoryThemePreferenceRepository(),
    );
  });

  test('material theme maps the selected accent to semantic colors', () {
    ThemeController.instance.setColor(SparkThemeColor.blue);

    final theme = SparkTheme.light();

    final palette = SparkPalette.light(ThemeController.instance.color);
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
      expect(
        contrast,
        greaterThanOrEqualTo(4.5),
        reason: '${color.label} must support white button content',
      );
    }
  });

  testWidgets('theme sheet shows all palettes and updates the accent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: SparkTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showProfileThemeSheet(context),
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

    expect(ThemeController.instance.color, SparkThemeColor.green);
  });

  testWidgets('theme sheet switches the appearance mode', (tester) async {
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
                onPressed: () => showProfileThemeSheet(context),
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

    expect(ThemeController.instance.mode, AppThemeMode.dark);
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
      SparkPalette.dark(ThemeController.instance.color).canvas,
    );
  });
}
