import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';

void main() {
  setUp(() async {
    await ThemeController.instance.configure(
      InMemoryThemePreferenceRepository(),
    );
  });

  test('material theme maps the selected accent to semantic colors', () {
    ThemeController.instance.setColor(PaperThemeColor.blue);

    final theme = SparkTheme.light();

    expect(theme.colorScheme.primary, PaperThemeColor.blue.value);
    expect(theme.colorScheme.primaryContainer, PaperThemeColor.blue.soft);
    expect(theme.colorScheme.surface, SparkColors.card);
    expect(theme.colorScheme.onSurface, SparkColors.ink);
    expect(theme.colorScheme.error, SparkColors.danger);
    expect(
      theme.inputDecorationTheme.fillColor,
      SparkColors.surfaceMuted,
    );
    expect(theme.scaffoldBackgroundColor, SparkColors.canvas);
  });

  test('theme accents keep readable contrast with white content', () {
    for (final color in PaperThemeColor.values) {
      final contrast = 1.05 / (color.value.computeLuminance() + 0.05);
      expect(
        contrast,
        greaterThanOrEqualTo(4.5),
        reason: '${color.label} must support white button content',
      );
    }
  });

  testWidgets('theme sheet shows all palettes and updates the accent',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: SparkTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPaperThemeSheet(context),
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
    for (final color in PaperThemeColor.values) {
      expect(find.byKey(ValueKey('paper-theme-${color.name}')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('paper-theme-green')));
    await tester.pumpAndSettle();

    expect(ThemeController.instance.color, PaperThemeColor.green);
  });
}
