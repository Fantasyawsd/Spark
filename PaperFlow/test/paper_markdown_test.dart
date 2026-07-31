import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/papers/presentation/widgets/paper_markdown.dart';

void main() {
  group('GeneratedMarkdownStabilizer', () {
    test('temporarily closes unfinished rich text delimiters', () {
      expect(
        GeneratedMarkdownStabilizer.stabilize('**结论'),
        '**结论**',
      );
      expect(
        GeneratedMarkdownStabilizer.stabilize(r'公式 $E=mc^2'),
        r'公式 $E=mc^2$',
      );
      expect(
        GeneratedMarkdownStabilizer.stabilize('```dart\nfinal value = 1;'),
        '```dart\nfinal value = 1;\n```',
      );
    });

    test('does not modify completed Markdown', () {
      const completed = r'**结论**：$E=mc^2$';
      expect(GeneratedMarkdownStabilizer.stabilize(completed), completed);
    });
  });

  group('PaperMarkdownPreprocessor', () {
    test('normalizes alternate delimiters and closes incomplete formulas', () {
      expect(
        PaperMarkdownPreprocessor.prepare(r'值为 \(\theta + \epsilon\)'),
        r'值为 $\theta + \epsilon$',
      );
      expect(
        PaperMarkdownPreprocessor.prepare(r'公式 $E=mc^2'),
        r'公式 $E=mc^2$',
      );
    });

    test('keeps simple Greek symbols inline as readable Unicode', () {
      expect(
        PaperMarkdownPreprocessor.prepare(r'其中 $\varepsilon$ 比例'),
        '其中 ε 比例',
      );
      expect(
        PaperMarkdownPreprocessor.prepare(r'趋于 $\infty$'),
        '趋于 ∞',
      );
    });

    test('falls back to readable Unicode when formula structure is invalid',
        () {
      final fallback = PaperMarkdownPreprocessor.prepare(
        r'极限 $\theta \to \infty_{',
      );
      expect(fallback, isNot(contains(r'$')));
      expect(fallback, contains('θ'));
      expect(fallback, contains('∞'));
    });
  });

  testWidgets('paper Markdown renders inline and block LaTeX', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaperMarkdown(
              data: r'行内公式 $E=mc^2$。' '\n\n' r'$$\frac{a}{b}$$',
              styleSheet: paperReaderMarkdownStyle(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('行内公式 '), findsOneWidget);
    expect(
      find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'Math'),
      findsNWidgets(2),
    );
  });

  test('does not normalize Markdown syntax inside fenced code', () {
    const source =
        '```python\nfinal value = \$raw\nif (value) {\n  print(value);\n}\n```';
    expect(PaperMarkdownPreprocessor.prepare(source), source);
  });

  testWidgets('renders fenced code with a direct copy action', (tester) async {
    const code = '```dart\nfinal value = 42;\n```';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperMarkdown(
            data: code,
            styleSheet: paperAiMarkdownStyle(),
          ),
        ),
      ),
    );

    expect(find.textContaining('final value = 42;'), findsOneWidget);
    final copyButton = find.byIcon(Icons.copy_rounded);
    expect(copyButton, findsOneWidget);

    await tester.tap(copyButton);
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard?.text, 'final value = 42;');
  });
}
