import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../../core/theme/paperflow_theme.dart';

/// The single Markdown rendering path used by paper content and AI output.
///
/// Generated text can end a streaming frame with an unfinished Markdown or
/// LaTeX delimiter. [stabilizeGeneratedSyntax] temporarily closes that
/// delimiter so the same content does not jump from plain text to rich text
/// when the final stream chunk arrives.
class PaperMarkdown extends StatelessWidget {
  const PaperMarkdown({
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
    final markdown = PaperMarkdownPreprocessor.prepare(
      data,
      stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
    );
    final bodyStyle = styleSheet.p ?? DefaultTextStyle.of(context).style;

    return MarkdownBody(
      data: markdown,
      selectable: selectable,
      // Source abstracts are often line-wrapped by an upstream API. Markdown
      // soft breaks should therefore flow as spaces instead of forced rows.
      softLineBreak: false,
      extensionSet: md.ExtensionSet(
        <md.BlockSyntax>[
          LatexBlockSyntax(),
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        ],
        <md.InlineSyntax>[
          LatexInlineSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      builders: <String, MarkdownElementBuilder>{
        'latex': LatexElementBuilder(textStyle: bodyStyle),
        'pre': _CodeBlockBuilder(),
      },
      styleSheet: styleSheet,
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent.trimRight();
    if (code.isEmpty) return const SizedBox.shrink();
    return _MarkdownCodeBlock(
      code: code,
      language: _language(element),
      textStyle: preferredStyle ?? parentStyle,
    );
  }

  String? _language(md.Element element) {
    final codeElement = element.children
        ?.whereType<md.Element>()
        .cast<md.Element?>()
        .firstWhere((child) => child != null && child.tag == 'code',
            orElse: () => null);
    final className = codeElement?.attributes['class'];
    if (className == null) return null;
    return className.replaceFirst(RegExp(r'^language-'), '').trim();
  }
}

class _MarkdownCodeBlock extends StatelessWidget {
  const _MarkdownCodeBlock({
    required this.code,
    required this.language,
    required this.textStyle,
  });

  final String code;
  final String? language;
  final TextStyle? textStyle;

  Future<void> _copy() {
    return Clipboard.setData(ClipboardData(text: code));
  }

  @override
  Widget build(BuildContext context) {
    final codeStyle = (textStyle ?? const TextStyle()).copyWith(
      color: const Color(0xFFE9EDF5),
      fontFamily: 'monospace',
      fontSize: textStyle?.fontSize ?? 13,
      height: 1.45,
    );
    return Container(
      key: ValueKey('paper-code-block-${code.hashCode}'),
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language == null || language!.isEmpty ? '代码' : language!,
                    style: const TextStyle(
                      color: Color(0xFFB8C1D1),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('paper-code-copy-${code.hashCode}'),
                  tooltip: '复制代码',
                  onPressed: _copy,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: Color(0xFFB8C1D1),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SelectableText(code, style: codeStyle),
          ),
        ],
      ),
    );
  }
}

const paperReaderBodyTextStyle = TextStyle(
  color: PaperFlowColors.ink,
  fontSize: 17,
  height: 1.28,
);

MarkdownStyleSheet paperReaderMarkdownStyle() {
  const body = paperReaderBodyTextStyle;
  return MarkdownStyleSheet(
    p: body,
    h1: body.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
    h2: body.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
    h3: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
    listBullet: body,
    strong: const TextStyle(fontWeight: FontWeight.w700),
    code: const TextStyle(
      color: Color(0xFFE9EDF5),
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.45,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: Color(0xFF172033),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    blockSpacing: 7,
    listIndent: 20,
  );
}

MarkdownStyleSheet paperAiMarkdownStyle({
  Color color = PaperFlowColors.ink,
  bool reasoning = false,
}) {
  final body = TextStyle(
    color: color,
    fontSize: reasoning ? 12 : 13.5,
    height: reasoning ? 1.36 : 1.38,
  );
  return MarkdownStyleSheet(
    p: body,
    h1: body.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
    h2: body.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
    h3: body.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
    listBullet: body,
    strong: TextStyle(color: color, fontWeight: FontWeight.w700),
    code: TextStyle(
      color: reasoning ? PaperFlowColors.muted : const Color(0xFFE9EDF5),
      fontFamily: 'monospace',
      fontSize: reasoning ? 11 : 12.5,
      height: 1.45,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: Color(0xFF172033),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    blockSpacing: reasoning ? 3 : 7,
    listIndent: reasoning ? 16 : 19,
  );
}

/// Normalizes the LaTeX forms commonly returned by paper APIs and LLMs.
///
/// The preprocessor favors readable text over exposing raw delimiters. It
/// converts `\\(...\\)` / `\\[...\\]` to the single Markdown-LaTeX path,
/// repairs a likely unfinished trailing formula, and drops delimiters when the
/// formula is structurally unsafe to render.
class PaperMarkdownPreprocessor {
  const PaperMarkdownPreprocessor._();

  static String prepare(
    String source, {
    bool stabilizeGeneratedSyntax = false,
  }) {
    if (source.isEmpty) return source;
    final codeBlocks = <String>[];
    var normalized = source.replaceAllMapped(
      RegExp(r'```[\s\S]*?```'),
      (match) {
        final token = '\u0000PAPERFLOW_CODE_${codeBlocks.length}\u0000';
        codeBlocks.add(match.group(0)!);
        return token;
      },
    );
    normalized = normalized
        .replaceAll(r'\[', r'$$')
        .replaceAll(r'\]', r'$$')
        .replaceAll(r'\(', r'$')
        .replaceAll(r'\)', r'$');

    if (stabilizeGeneratedSyntax || _containsLikelyLatex(normalized)) {
      normalized = GeneratedMarkdownStabilizer.stabilize(normalized);
    }

    // Simple Greek symbols do not need a separate Math widget. Keeping them
    // as Unicode avoids orphaning a tiny inline formula on its own line when
    // a narrow reading column wraps Chinese text.
    normalized = _replaceSimpleSymbolMath(normalized);

    if (!_hasBalancedBraces(normalized) || _hasUnbalancedDollar(normalized)) {
      normalized = readableLatexFallback(normalized);
    }
    for (var index = 0; index < codeBlocks.length; index++) {
      normalized = normalized.replaceAll(
        '\u0000PAPERFLOW_CODE_$index\u0000',
        codeBlocks[index],
      );
    }
    return normalized;
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
          r'(?<!\$)\$\s*\\(epsilon|varepsilon|theta|infty|alpha|beta|gamma|lambda|mu|pi)\s*\$(?!\$)'),
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
    final visible = source.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    var count = 0;
    for (var index = 0; index < visible.length; index++) {
      if (visible[index] == r'$'[0] &&
          !GeneratedMarkdownStabilizer._isEscaped(visible, index)) {
        count++;
      }
    }
    return count.isOdd;
  }
}

/// Repairs only unfinished trailing delimiters. It never changes completed
/// Markdown, so the final frame and the streaming frames use the same parser.
class GeneratedMarkdownStabilizer {
  const GeneratedMarkdownStabilizer._();

  static String stabilize(String source) {
    if (source.isEmpty) return source;

    final fenceMatches = RegExp(
      r'(^|\n)[ \t]*```',
      multiLine: true,
    ).allMatches(source).length;
    if (fenceMatches.isOdd) return '$source\n```';

    final visible = source.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      '',
    );
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
    final looksLikeMath =
        RegExp(r'[\\^_={}+*/]|[A-Za-z]\s*\(').hasMatch(fragment);
    if (looksLikeMath) pending.add(_PendingCloser(opening, r'$'));
  }

  static bool _startsWithUnescaped(
    String source,
    String delimiter,
    int index,
  ) {
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
