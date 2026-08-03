import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
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

  group('PaperLatexInlineSyntax', () {
    List<md.Element> latexElements(String source) {
      final document = md.Document(
        extensionSet: md.ExtensionSet(
          md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          <md.InlineSyntax>[
            PaperLatexInlineSyntax(),
            ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          ],
        ),
      );
      final nodes =
          document.parseLines(LineSplitter.split(source).toList());
      final found = <md.Element>[];
      void visit(md.Node node) {
        if (node is md.Element) {
          if (node.tag == 'latex') found.add(node);
          for (final child in node.children ?? const <md.Node>[]) {
            visit(child);
          }
        }
      }

      for (final node in nodes) {
        visit(node);
      }
      return found;
    }

    test('closes a formula followed by a hyphen without swallowing `\$`',
        () {
      final elements = latexElements(
        r'for all $(\varepsilon,\delta)$-DP mechanisms with $\varepsilon > 0$.',
      );
      expect(elements, hasLength(2));
      expect(elements[0].textContent, r'(\varepsilon,\delta)');
      expect(elements[1].textContent, r'\varepsilon > 0');
      expect(elements[0].textContent, isNot(contains(r'$')));
      expect(elements[1].textContent, isNot(contains(r'$')));
      expect(elements[0].attributes['MathStyle'], 'text');
    });

    test('keeps surrounding text intact when a formula adjoins a word', () {
      final elements = latexElements(
        r'with $\epsilon$-greedy exploration and $\mathcal{O}(n)$ cost.',
      );
      expect(elements, hasLength(2));
      expect(elements[0].textContent, r'\epsilon');
      expect(elements[1].textContent, r'\mathcal{O}(n)');
    });

    test('parses inline formulas inside Chinese text', () {
      final elements = latexElements(
        r'其中 $h_{\mathrm{DAP}}$ 表示带宽，$\beta > 2$ 为平滑参数。',
      );
      expect(elements, hasLength(2));
      expect(elements[0].textContent, r'h_{\mathrm{DAP}}');
      expect(elements[1].textContent, r'\beta > 2');
    });

    test('marks single-line `\$\$...\$\$` as display style', () {
      final elements = latexElements(r'公式 $$\frac{a}{b}$$ 居中显示');
      expect(elements, hasLength(1));
      expect(elements[0].textContent, r'\frac{a}{b}');
      expect(elements[0].attributes['MathStyle'], 'display');
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

    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.tap(copyButton);
    await tester.pump();
    expect(copiedText, 'final value = 42;');
  });
}
