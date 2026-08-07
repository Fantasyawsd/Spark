import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:spark/src/core/widgets/spark_markdown.dart';

void main() {
  group('GeneratedMarkdownStabilizer', () {
    test('temporarily closes unfinished rich text delimiters', () {
      expect(GeneratedMarkdownStabilizer.stabilize('**结论'), '**结论**');
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

    test('temporarily closes unfinished italic and strikethrough', () {
      expect(GeneratedMarkdownStabilizer.stabilize('*重要'), '*重要*');
      expect(
        GeneratedMarkdownStabilizer.stabilize('~~删除'),
        '~~删除~~',
      );
    });

    test('keeps completed italic, bold and strikethrough unchanged', () {
      const completed = '*斜体* 与 **加粗** 与 ~~删除线~~';
      expect(GeneratedMarkdownStabilizer.stabilize(completed), completed);
    });

    test('unfinished bold is not confused with a single italic asterisk', () {
      expect(GeneratedMarkdownStabilizer.stabilize('**加粗'), '**加粗**');
      expect(GeneratedMarkdownStabilizer.stabilize('*斜体* 与 **加粗'),
          '*斜体* 与 **加粗**');
    });
  });

  group('SparkMarkdownPreprocessor', () {
    test('normalizes alternate delimiters and closes incomplete formulas', () {
      expect(
        SparkMarkdownPreprocessor.prepare(r'值为 \(\theta + \epsilon\)'),
        r'值为 $\theta + \epsilon$',
      );
      expect(SparkMarkdownPreprocessor.prepare(r'公式 $E=mc^2'), r'公式 $E=mc^2$');
    });

    test('keeps simple Greek symbols inline as readable Unicode', () {
      expect(
        SparkMarkdownPreprocessor.prepare(r'其中 $\varepsilon$ 比例'),
        '其中 ε 比例',
      );
      expect(SparkMarkdownPreprocessor.prepare(r'趋于 $\infty$'), '趋于 ∞');
    });

    test(
      'falls back to readable Unicode when formula structure is invalid',
      () {
        final fallback = SparkMarkdownPreprocessor.prepare(
          r'极限 $\theta \to \infty_{',
        );
        expect(fallback, isNot(contains(r'$')));
        expect(fallback, contains('θ'));
        expect(fallback, contains('∞'));
      },
    );

    test('converts abstract text commands outside math to Markdown', () {
      expect(
        SparkMarkdownPreprocessor.prepare(r'We present \textbf{ViewMind3D}'),
        'We present **ViewMind3D**',
      );
      expect(
        SparkMarkdownPreprocessor.prepare(r'an \emph{important} result'),
        'an *important* result',
      );
      expect(
        SparkMarkdownPreprocessor.prepare(r'\textit{prior} work'),
        '*prior* work',
      );
    });

    test('leaves text commands inside math mode untouched', () {
      expect(
        SparkMarkdownPreprocessor.prepare(
          r'where $\textbf{x} \sim \mathcal{N}$',
        ),
        r'where $\textbf{x} \sim \mathcal{N}$',
      );
    });

    test('keeps formulas intact when text commands are converted', () {
      expect(
        SparkMarkdownPreprocessor.prepare(
          r'\textbf{ViewMind3D} achieves $\beta > 2$ on \emph{benchmarks}',
        ),
        r'**ViewMind3D** achieves $\beta > 2$ on *benchmarks*',
      );
    });
  });

  group('SparkLatexInlineSyntax', () {
    List<md.Element> latexElements(String source) {
      final document = md.Document(
        extensionSet: md.ExtensionSet(
          md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          <md.InlineSyntax>[
            SparkLatexInlineSyntax(),
            ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          ],
        ),
      );
      final nodes = document.parseLines(LineSplitter.split(source).toList());
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

    test('closes a formula followed by a hyphen without swallowing `\$`', () {
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

  testWidgets('long inline formulas fit a mobile reply width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final formula = List.filled(4, r'\mathrm{attention}').join(r' + ');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SparkMarkdown(
              data: '回复中使用 \$$formula\$ 进行归一化。',
              styleSheet: paperReaderMarkdownStyle(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline formulas render without a wrapping scroll view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SparkMarkdown(
            data: r'行内公式 $E=mc^2$ 与文本同行。',
            styleSheet: paperReaderMarkdownStyle(),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final mathWidget = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'Math',
    );
    expect(mathWidget, findsOneWidget);
    // 行内公式不能包在 SingleChildScrollView 里，否则会被顶成独立一行。
    expect(
      find.ancestor(
        of: mathWidget,
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'wrapped text keeps inline formulas and punctuation in one flow',
    (tester) async {
      const prefix = 'The density belongs to a smooth class ';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SparkMarkdown(
                data:
                    r'The density belongs to a smooth class $\beta > 2$, after',
                styleSheet: paperReaderMarkdownStyle(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final mathWidget = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'Math',
      );
      expect(mathWidget, findsOneWidget);

      final paragraphFinder = find.ancestor(
        of: mathWidget,
        matching: find.byType(Text),
      );
      expect(
        paragraphFinder,
        findsOneWidget,
        reason: 'Inline math must be a WidgetSpan inside one text paragraph.',
      );
      expect(find.byType(SelectionArea), findsOneWidget);

      final richTextFinder = find.ancestor(
        of: mathWidget,
        matching: find.byType(RichText),
      );
      expect(richTextFinder, findsOneWidget);
      final richText = tester.widget<RichText>(richTextFinder);
      expect(
        richText.text.toPlainText(includePlaceholders: true),
        '$prefix\uFFFC, after',
      );
      final paragraph = tester.renderObject<RenderParagraph>(richTextFinder);
      final paragraphRect = tester.getRect(richTextFinder);
      final mathRect = tester.getRect(mathWidget).shift(-paragraphRect.topLeft);
      final precedingWordBox = paragraph
          .getBoxesForSelection(
            const TextSelection(
              baseOffset: prefix.length - 6,
              extentOffset: prefix.length - 1,
            ),
          )
          .single;
      final punctuationBox = paragraph
          .getBoxesForSelection(
            const TextSelection(
              baseOffset: prefix.length + 1,
              extentOffset: prefix.length + 2,
            ),
          )
          .single;

      bool overlapsVertically(Rect first, Rect second) {
        return first.bottom > second.top && second.bottom > first.top;
      }

      expect(
        overlapsVertically(mathRect, precedingWordBox.toRect()),
        isTrue,
        reason: 'The formula must use the remaining space after the last word. '
            'word=${precedingWordBox.toRect()} math=$mathRect',
      );
      expect(
        overlapsVertically(mathRect, punctuationBox.toRect()),
        isTrue,
        reason: 'The following punctuation must stay beside the formula. '
            'math=$mathRect punctuation=${punctuationBox.toRect()}',
      );
    },
  );

  testWidgets('paper Markdown renders inline and block LaTeX', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SparkMarkdown(
              data: r'行内公式 $E=mc^2$。'
                  '\n\n'
                  r'$$\frac{a}{b}$$',
              styleSheet: paperReaderMarkdownStyle(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('行内公式', findRichText: true), findsOneWidget);
    final mathWidgets = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'Math',
    );
    expect(mathWidgets, findsNWidgets(2));
    expect(
      tester.getRect(mathWidgets.at(1)).top,
      greaterThan(tester.getRect(mathWidgets.at(0)).bottom),
      reason: 'Display math must remain in its own block below inline text.',
    );
  });

  test('does not normalize Markdown syntax inside fenced code', () {
    const source =
        '```python\nfinal value = \$raw\nif (value) {\n  print(value);\n}\n```';
    expect(SparkMarkdownPreprocessor.prepare(source), source);
  });

  testWidgets('renders fenced code with a direct copy action', (tester) async {
    const code = '```dart\nfinal value = 42;\n```';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SparkMarkdown(data: code, styleSheet: sparkMarkdownStyle()),
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
