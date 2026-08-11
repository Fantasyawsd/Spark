import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/spark_font_sizes.dart';
import '../theme/spark_theme.dart';
import 'spark_code_highlight.dart';

/// Inline LaTeX syntax that replaces [LatexInlineSyntax] from
/// flutter_markdown_plus_latex.
///
/// The package regex ends with a lookahead `(?=[\s?!.,：？！。，：]|$)` that
/// only accepts a closing `$` when the next character is whitespace or a
/// punctuation mark. A formula immediately followed by other characters (e.g.
/// the `-` in `$(\varepsilon,\delta)$-DP`) fails to close, and the lazy match
/// swallows everything up to the next `$`. The captured content then still
/// contains a `$`, which Math.tex rejects with
/// `Parser Error: Can't use function '$' in math mode`.
///
/// This syntax closes a formula at the nearest unescaped delimiter regardless
/// of the following character, and never passes a `$` inside the content to
/// the Math widget.
class SparkLatexInlineSyntax extends md.InlineSyntax {
  SparkLatexInlineSyntax() : super(_patternSource);

  // `$$...$$` must be tried before `$...$`, otherwise a `$$` block is caught
  // half-open by the single `$` rule.
  static final String _patternSource = r'\$\$(?:\\[\s\S]|[^$\n])*?\$\$'
      r'|\$(?:\\[\s\S]|[^$\n])*?\$'
      r'|\\\[(?:\\[\s\S]|[^\\\n])*?\\\]'
      r'|\\\((?:\\[\s\S]|[^\\\n])*?\\\)';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final raw = match.group(0) ?? '';
    String equation;
    String mathStyle;
    if (raw.startsWith(r'$$') && raw.endsWith(r'$$') && raw.length >= 4) {
      equation = raw.substring(2, raw.length - 2);
      mathStyle = 'display';
    } else if (raw.startsWith(r'\[') &&
        raw.endsWith(r'\]') &&
        raw.length >= 4) {
      equation = raw.substring(2, raw.length - 2);
      mathStyle = 'display';
    } else if (raw.startsWith(r'\(') &&
        raw.endsWith(r'\)') &&
        raw.length >= 4) {
      equation = raw.substring(2, raw.length - 2);
      mathStyle = 'text';
    } else if (raw.startsWith(r'$') && raw.endsWith(r'$') && raw.length >= 2) {
      equation = raw.substring(1, raw.length - 1);
      mathStyle = 'text';
    } else {
      parser.addNode(md.Text(raw));
      return true;
    }
    final element = md.Element.text('latex', equation);
    element.attributes['MathStyle'] = mathStyle;
    parser.addNode(element);
    return true;
  }
}

/// Replaces [LatexElementBuilder] from flutter_markdown_plus_latex.
///
/// The package builder wraps every formula in a [SingleChildScrollView]. As an
/// inline [WidgetSpan] inside a paragraph that viewport has no bounded width,
/// so it forces the formula onto its own line and breaks the surrounding text
/// flow. Returning a [Text] with a [WidgetSpan] lets flutter_markdown_plus merge
/// the formula with the surrounding [TextSpan]s into one paragraph.
class SparkLatexElementBuilder extends MarkdownElementBuilder {
  SparkLatexElementBuilder({this.textStyle, this.textScaleFactor});

  /// The style to apply to the formula text.
  final TextStyle? textStyle;

  /// The text scale factor to apply to the formula.
  final double? textScaleFactor;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    if (text.isEmpty) {
      return const Text('');
    }

    MathStyle mathStyle;
    switch (element.attributes['MathStyle']) {
      case 'text':
        mathStyle = MathStyle.text;
      case 'display':
        mathStyle = MathStyle.display;
      default:
        mathStyle = MathStyle.text;
    }

    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Math.tex(
                text,
                textStyle: textStyle,
                mathStyle: mathStyle,
                textScaleFactor: textScaleFactor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The single Markdown rendering path used by paper content and AI output.
///
/// Generated text can end a streaming frame with an unfinished Markdown or
/// LaTeX delimiter. [stabilizeGeneratedSyntax] temporarily closes that
/// delimiter so the same content does not jump from plain text to rich text
/// when the final stream chunk arrives.
class SparkMarkdown extends StatelessWidget {
  const SparkMarkdown({
    super.key,
    required this.data,
    required this.styleSheet,
    this.selectable = true,
    this.stabilizeGeneratedSyntax = false,
  });

  final String data;
  final MarkdownStyleSheet styleSheet;
  final bool selectable;
  final bool stabilizeGeneratedSyntax;

  @override
  Widget build(BuildContext context) {
    final markdown = SparkMarkdownPreprocessor.prepare(
      data,
      stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
    );
    final bodyStyle = styleSheet.p ?? DefaultTextStyle.of(context).style;

    Widget markdownBody(String value) {
      return MarkdownBody(
        data: value,
        selectable: false,
        softLineBreak: false,
        extensionSet: md.ExtensionSet(
          <md.BlockSyntax>[
            LatexBlockSyntax(),
            ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          ],
          <md.InlineSyntax>[
            SparkLatexInlineSyntax(),
            ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          ],
        ),
        builders: <String, MarkdownElementBuilder>{
          'latex': SparkLatexElementBuilder(textStyle: bodyStyle),
          'pre': SparkCodeBlockBuilder(textStyle: styleSheet.code),
        },
        styleSheet: styleSheet,
      );
    }

    final content = markdownBody(markdown);

    if (!selectable) {
      return SelectionContainer.disabled(child: content);
    }
    if (SelectionContainer.maybeOf(context) != null) {
      return content;
    }
    return SelectionArea(child: content);
  }
}

/// 阅读正文测量样式。颜色对排版测量无影响，故不含颜色；
/// 展示路径由 [paperReaderMarkdownStyle] 按主题补色。
const paperReaderBodyTextStyle = TextStyle(
  fontSize: SparkFontSizes.title,
  height: 1.28,
);

MarkdownStyleSheet paperReaderMarkdownStyle(BuildContext context) {
  final palette = SparkColors.of(context);
  final body = paperReaderBodyTextStyle.copyWith(color: palette.ink);
  return MarkdownStyleSheet(
    a: body.copyWith(
      color: palette.primary,
      decoration: TextDecoration.underline,
    ),
    p: body,
    h1: body.copyWith(
      fontSize: SparkFontSizes.headline,
      fontWeight: FontWeight.w800,
    ),
    h2: body.copyWith(
      fontSize: SparkFontSizes.headlineSmall,
      fontWeight: FontWeight.w800,
    ),
    h3: body.copyWith(
      fontSize: SparkFontSizes.titleLarge,
      fontWeight: FontWeight.w700,
    ),
    listBullet: body,
    strong: const TextStyle(fontWeight: FontWeight.w700),
    code: TextStyle(
      color: palette.primary,
      fontFamily: 'JetBrainsMono',
      fontSize: SparkFontSizes.bodySmall,
      height: 1.45,
    ),
    blockquote: body.copyWith(fontStyle: FontStyle.italic),
    blockquoteDecoration: BoxDecoration(
      color: palette.surfaceMuted,
      border: Border(left: BorderSide(color: palette.lineStrong, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
    codeblockPadding: EdgeInsets.zero,
    codeblockDecoration: const BoxDecoration(),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: palette.line)),
    ),
    blockSpacing: 7,
    listIndent: 20,
  );
}

MarkdownStyleSheet sparkMarkdownStyle(
  BuildContext context, {
  Color? color,
  bool reasoning = false,
}) {
  final palette = SparkColors.of(context);
  final effectiveColor = color ?? palette.ink;
  final body = TextStyle(
    color: effectiveColor,
    fontSize: reasoning ? 12 : 14.2,
    height: reasoning ? 1.4 : 1.5,
  );
  return MarkdownStyleSheet(
    a: body.copyWith(
      color: palette.primary,
      decoration: TextDecoration.underline,
    ),
    p: body,
    h1: body.copyWith(
      fontSize: SparkFontSizes.titleLarge,
      fontWeight: FontWeight.w800,
    ),
    h2: body.copyWith(
      fontSize: SparkFontSizes.titleSmall,
      fontWeight: FontWeight.w800,
    ),
    h3: body.copyWith(
      fontSize: SparkFontSizes.body,
      fontWeight: FontWeight.w700,
    ),
    listBullet: body,
    strong: TextStyle(color: effectiveColor, fontWeight: FontWeight.w700),
    code: TextStyle(
      color: reasoning ? palette.muted : palette.primary,
      fontFamily: 'JetBrainsMono',
      fontSize: reasoning ? 11 : 12.8,
      height: 1.5,
    ),
    blockquote: body.copyWith(fontStyle: FontStyle.italic),
    blockquoteDecoration: BoxDecoration(
      color: palette.surfaceMuted,
      border: Border(left: BorderSide(color: palette.lineStrong, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
    codeblockPadding: EdgeInsets.zero,
    codeblockDecoration: const BoxDecoration(),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: palette.line)),
    ),
    blockSpacing: reasoning ? 4 : 9,
    listIndent: reasoning ? 16 : 20,
  );
}

/// Normalizes the LaTeX forms commonly returned by paper APIs and LLMs.
///
/// The preprocessor favors readable text over exposing raw delimiters. It
/// converts `\\(...\\)` / `\\[...\\]` to the single Markdown-LaTeX path,
/// repairs a likely unfinished trailing formula, and drops delimiters when the
/// formula is structurally unsafe to render.
class SparkMarkdownPreprocessor {
  const SparkMarkdownPreprocessor._();

  static String prepare(
    String source, {
    bool stabilizeGeneratedSyntax = false,
  }) {
    if (source.isEmpty) return source;
    final stabilized = stabilizeGeneratedSyntax
        ? GeneratedMarkdownStabilizer.stabilize(source)
        : source;
    final protectedCode = _FencedCodeProtection.extract(stabilized);
    var normalized = protectedCode.visible;
    normalized = normalized
        .replaceAll(r'\[', r'$$')
        .replaceAll(r'\]', r'$$')
        .replaceAll(r'\(', r'$')
        .replaceAll(r'\)', r'$');
    normalized = _convertLatexTextCommands(normalized);

    if (!stabilizeGeneratedSyntax && _containsLikelyLatex(normalized)) {
      normalized = GeneratedMarkdownStabilizer.stabilize(normalized);
    }

    // Simple Greek symbols do not need a separate Math widget. Keeping them
    // as Unicode avoids orphaning a tiny inline formula on its own line when
    // a narrow reading column wraps Chinese text.
    normalized = _replaceSimpleSymbolMath(normalized);

    if (!_hasBalancedBraces(normalized) || _hasUnbalancedDollar(normalized)) {
      normalized = readableLatexFallback(normalized);
    }
    return protectedCode.restore(normalized);
  }

  static String readableLatexFallback(String source) {
    var fallback = source
        .replaceAll(r'$$', '')
        .replaceAll(r'$', '')
        .replaceAll(r'\[', '')
        .replaceAll(r'\]', '')
        .replaceAll(r'\(', '')
        .replaceAll(r'\)', '');
    const symbols = <String, String>{
      r'\epsilon': 'ε',
      r'\varepsilon': 'ε',
      r'\theta': 'θ',
      r'\infty': '∞',
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\lambda': 'λ',
      r'\mu': 'μ',
      r'\pi': 'π',
      r'\sum': 'Σ',
      r'\times': '×',
      r'\leq': '≤',
      r'\geq': '≥',
      r'\neq': '≠',
    };
    for (final entry in symbols.entries) {
      fallback = fallback.replaceAll(entry.key, entry.value);
    }
    return fallback.replaceAllMapped(
      RegExp(r'\\([A-Za-z]+)'),
      (match) => match.group(1) ?? '',
    );
  }

  /// Converts arXiv abstract text-formatting commands outside math to their
  /// Markdown equivalents: `\textbf{X}` → `**X**`, `\emph{X}`/`\textit{X}` →
  /// `*X*`. Formulas (`$...$`) are protected first so a `\textbf` inside math
  /// mode is left untouched; the argument is simple text without nested
  /// braces.
  static String _convertLatexTextCommands(String source) {
    final formulas = <String>[];
    var working = source.replaceAllMapped(
      RegExp(r'\$\$(?:\\[\s\S]|[^$\n])*?\$\$|\$(?:\\[\s\S]|[^$\n])*?\$'),
      (match) {
        final token = '\u0000SPARK_MATH_${formulas.length}\u0000';
        formulas.add(match.group(0)!);
        return token;
      },
    );
    working = working.replaceAllMapped(
      RegExp(r'\\(textbf|emph|textit)\{([^{}]+)\}'),
      (match) => match.group(1) == 'textbf'
          ? '**${match.group(2)}**'
          : '*${match.group(2)}*',
    );
    for (var index = 0; index < formulas.length; index++) {
      working = working.replaceAll(
        '\u0000SPARK_MATH_$index\u0000',
        formulas[index],
      );
    }
    return working;
  }

  static String _replaceSimpleSymbolMath(String source) {
    const symbols = <String, String>{
      'epsilon': 'ε',
      'varepsilon': 'ε',
      'theta': 'θ',
      'infty': '∞',
      'alpha': 'α',
      'beta': 'β',
      'gamma': 'γ',
      'lambda': 'λ',
      'mu': 'μ',
      'pi': 'π',
    };
    return source.replaceAllMapped(
      RegExp(
        r'(?<!\$)\$\s*\\(epsilon|varepsilon|theta|infty|alpha|beta|gamma|lambda|mu|pi)\s*\$(?!\$)',
      ),
      (match) => symbols[match.group(1)] ?? match.group(0)!,
    );
  }

  static bool _containsLikelyLatex(String source) {
    return source.contains(r'$') ||
        source.contains(r'\(') ||
        source.contains(r'\[') ||
        RegExp(r'\\[A-Za-z]+').hasMatch(source);
  }

  static bool _hasBalancedBraces(String source) {
    var depth = 0;
    for (var index = 0; index < source.length; index++) {
      if (GeneratedMarkdownStabilizer._isEscaped(source, index)) continue;
      if (source[index] == '{') depth++;
      if (source[index] == '}') depth--;
      if (depth < 0) return false;
    }
    return depth == 0;
  }

  static bool _hasUnbalancedDollar(String source) {
    var count = 0;
    for (var index = 0; index < source.length; index++) {
      if (source[index] == r'$'[0] &&
          !GeneratedMarkdownStabilizer._isEscaped(source, index)) {
        count++;
      }
    }
    return count.isOdd;
  }
}

class _FencedCodeProtection {
  const _FencedCodeProtection._({
    required this.visible,
    required this.blocks,
    required this.pendingFence,
  });

  final String visible;
  final List<String> blocks;
  final String? pendingFence;

  static final _fencePattern = RegExp(r'^[ \t]{0,3}(`{3,}|~{3,})(.*)$');

  static _FencedCodeProtection extract(String source) {
    final visible = StringBuffer();
    final blocks = <String>[];
    StringBuffer? activeBlock;
    String? fenceCharacter;
    var fenceLength = 0;

    final lines = source.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final completeLine = index == lines.length - 1 ? line : '$line\n';
      final fenceMatch = _fencePattern.firstMatch(line);

      if (activeBlock == null) {
        if (fenceMatch == null) {
          visible.write(completeLine);
          continue;
        }
        final marker = fenceMatch.group(1)!;
        fenceCharacter = marker[0];
        fenceLength = marker.length;
        activeBlock = StringBuffer()..write(completeLine);
        continue;
      }

      activeBlock.write(completeLine);
      if (fenceMatch == null) continue;
      final marker = fenceMatch.group(1)!;
      final trailing = fenceMatch.group(2) ?? '';
      final closesFence = marker[0] == fenceCharacter &&
          marker.length >= fenceLength &&
          trailing.trim().isEmpty;
      if (!closesFence) continue;

      final token = _token(blocks.length);
      blocks.add(activeBlock.toString());
      visible.write(token);
      activeBlock = null;
      fenceCharacter = null;
      fenceLength = 0;
    }

    String? pendingFence;
    if (activeBlock != null) {
      final token = _token(blocks.length);
      blocks.add(activeBlock.toString());
      visible.write(token);
      pendingFence = List.filled(fenceLength, fenceCharacter).join();
    }
    return _FencedCodeProtection._(
      visible: visible.toString(),
      blocks: blocks,
      pendingFence: pendingFence,
    );
  }

  String restore(String source) {
    var restored = source;
    for (var index = 0; index < blocks.length; index++) {
      restored = restored.replaceAll(_token(index), blocks[index]);
    }
    return restored;
  }

  static String _token(int index) => '\u0000SPARK_CODE_$index\u0000';
}

/// Repairs only unfinished trailing delimiters. It never changes completed
/// Markdown, so the final frame and the streaming frames use the same parser.
class GeneratedMarkdownStabilizer {
  const GeneratedMarkdownStabilizer._();

  static String stabilize(String source) {
    if (source.isEmpty) return source;

    final protectedCode = _FencedCodeProtection.extract(source);
    if (protectedCode.pendingFence case final pendingFence?) {
      final separator = source.endsWith('\n') ? '' : '\n';
      return '$source$separator$pendingFence';
    }

    final visible = protectedCode.visible;
    final pendingClosers = <_PendingCloser>[];

    _collectPairedDelimiter(visible, r'\[', r'\]', pendingClosers);
    _collectPairedDelimiter(visible, r'\(', r'\)', pendingClosers);
    _collectSymmetricDelimiter(visible, r'$$', r'$$', pendingClosers);

    final withoutDisplayMath = visible.replaceAll(
      RegExp(r'\$\$[\s\S]*?\$\$'),
      '',
    );
    _collectLikelyInlineMath(withoutDisplayMath, pendingClosers);

    final withoutInlineCode = visible.replaceAll(RegExp(r'`[^`]*`'), '');
    _collectSymmetricDelimiter(withoutInlineCode, '`', '`', pendingClosers);
    _collectSymmetricDelimiter(withoutInlineCode, '**', '**', pendingClosers);
    _collectSymmetricDelimiter(withoutInlineCode, '__', '__', pendingClosers);
    _collectSymmetricDelimiter(withoutInlineCode, '~~', '~~', pendingClosers);
    _collectLikelyItalic(withoutInlineCode, pendingClosers);

    if (pendingClosers.isEmpty) return source;
    pendingClosers.sort((a, b) => b.position.compareTo(a.position));
    return source + pendingClosers.map((item) => item.value).join();
  }

  static void _collectPairedDelimiter(
    String source,
    String opening,
    String closing,
    List<_PendingCloser> pending,
  ) {
    final openings = <int>[];
    var index = 0;
    while (index < source.length) {
      if (_startsWithUnescaped(source, opening, index)) {
        openings.add(index);
        index += opening.length;
      } else if (_startsWithUnescaped(source, closing, index)) {
        if (openings.isNotEmpty) openings.removeLast();
        index += closing.length;
      } else {
        index++;
      }
    }
    for (final position in openings) {
      pending.add(_PendingCloser(position, closing));
    }
  }

  static void _collectSymmetricDelimiter(
    String source,
    String delimiter,
    String closing,
    List<_PendingCloser> pending,
  ) {
    final positions = <int>[];
    var index = 0;
    while (index <= source.length - delimiter.length) {
      if (_startsWithUnescaped(source, delimiter, index)) {
        positions.add(index);
        index += delimiter.length;
      } else {
        index++;
      }
    }
    if (positions.length.isOdd) {
      pending.add(_PendingCloser(positions.last, closing));
    }
  }

  /// 补全未闭合的斜体 `*`。加粗 `**` 已由 [_collectSymmetricDelimiter]
  /// 成对处理，这里只处理剩余的单星号：奇数个时补一个收尾星号。
  static void _collectLikelyItalic(
    String source,
    List<_PendingCloser> pending,
  ) {
    final positions = <int>[];
    for (var index = 0; index < source.length; index++) {
      if (source[index] == '*' && !_isEscaped(source, index)) {
        positions.add(index);
      }
    }
    if (positions.length.isOdd) {
      pending.add(_PendingCloser(positions.last, '*'));
    }
  }

  static void _collectLikelyInlineMath(
    String source,
    List<_PendingCloser> pending,
  ) {
    final positions = <int>[];
    for (var index = 0; index < source.length; index++) {
      if (source[index] == r'$'[0] && !_isEscaped(source, index)) {
        positions.add(index);
      }
    }
    if (positions.length.isEven) return;

    final opening = positions.last;
    final fragment = source.substring(opening + 1);
    final looksLikeMath = RegExp(
      r'[\\^_={}+*/]|[A-Za-z]\s*\(',
    ).hasMatch(fragment);
    if (looksLikeMath) pending.add(_PendingCloser(opening, r'$'));
  }

  static bool _startsWithUnescaped(String source, String delimiter, int index) {
    return source.startsWith(delimiter, index) && !_isEscaped(source, index);
  }

  static bool _isEscaped(String source, int index) {
    var slashCount = 0;
    for (var cursor = index - 1;
        cursor >= 0 && source[cursor] == r'\'[0];
        cursor--) {
      slashCount++;
    }
    return slashCount.isOdd;
  }
}

class _PendingCloser {
  const _PendingCloser(this.position, this.value);

  final int position;
  final String value;
}
