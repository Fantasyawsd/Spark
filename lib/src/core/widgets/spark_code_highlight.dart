import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../platform/spark_clipboard.dart';
import '../theme/spark_design_tokens.dart';
import '../theme/spark_font_sizes.dart';

enum SparkCodeTokenKind {
  plain,
  keyword,
  string,
  number,
  comment,
  function,
  type,
  property,
  operator,
  boolean,
}

class SparkCodeToken {
  const SparkCodeToken(this.text, this.kind);

  final String text;
  final SparkCodeTokenKind kind;
}

class SparkCodeTheme {
  const SparkCodeTheme({
    required this.background,
    required this.toolbarBackground,
    required this.border,
    required this.foreground,
    required this.keyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.function,
    required this.type,
    required this.property,
    required this.operator,
    required this.boolean,
  });

  const SparkCodeTheme.light()
      : this(
          background: const Color(0xFFFAFAFA),
          toolbarBackground: const Color(0xFFF0F0F0),
          border: const Color(0xFFD6D8DE),
          foreground: const Color(0xFF383A42),
          keyword: const Color(0xFFA626A4),
          string: const Color(0xFF50A14F),
          number: const Color(0xFFC18401),
          comment: const Color(0xFF9CA0A4),
          function: const Color(0xFF4078F2),
          type: const Color(0xFFC18401),
          property: const Color(0xFFE45649),
          operator: const Color(0xFF0184BC),
          boolean: const Color(0xFFC18401),
        );

  const SparkCodeTheme.dark()
      : this(
          background: const Color(0xFF282C34),
          toolbarBackground: const Color(0xFF21252B),
          border: const Color(0xFF3E4451),
          foreground: const Color(0xFFABB2BF),
          keyword: const Color(0xFFC678DD),
          string: const Color(0xFF98C379),
          number: const Color(0xFFD19A66),
          comment: const Color(0xFF5C6370),
          function: const Color(0xFF61AFEF),
          type: const Color(0xFFE5C07B),
          property: const Color(0xFFE06C75),
          operator: const Color(0xFF56B6C2),
          boolean: const Color(0xFFD19A66),
        );

  final Color background;
  final Color toolbarBackground;
  final Color border;
  final Color foreground;
  final Color keyword;
  final Color string;
  final Color number;
  final Color comment;
  final Color function;
  final Color type;
  final Color property;
  final Color operator;
  final Color boolean;

  static SparkCodeTheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const SparkCodeTheme.dark()
        : const SparkCodeTheme.light();
  }

  TextStyle styleFor(SparkCodeTokenKind kind) {
    final color = switch (kind) {
      SparkCodeTokenKind.keyword => keyword,
      SparkCodeTokenKind.string => string,
      SparkCodeTokenKind.number => number,
      SparkCodeTokenKind.comment => comment,
      SparkCodeTokenKind.function => function,
      SparkCodeTokenKind.type => type,
      SparkCodeTokenKind.property => property,
      SparkCodeTokenKind.operator => operator,
      SparkCodeTokenKind.boolean => boolean,
      SparkCodeTokenKind.plain => foreground,
    };
    return TextStyle(color: color);
  }

  TextStyle baseTextStyle({double? fontSize, double? height}) {
    return TextStyle(
      color: foreground,
      fontFamily: 'JetBrainsMono',
      fontSize: fontSize ?? 13,
      height: height ?? 1.45,
    );
  }
}

abstract final class SparkCodeTokenizer {
  static const supportedLanguages = <String>{
    'bash',
    'css',
    'dart',
    'go',
    'html',
    'java',
    'javascript',
    'json',
    'kotlin',
    'python',
    'rust',
    'shell',
    'sql',
    'swift',
    'typescript',
    'xml',
    'yaml',
  };

  static String normalizeLanguage(String? language) {
    final normalized = language?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'c++' => 'cpp',
      'c#' => 'csharp',
      'js' => 'javascript',
      'jsx' => 'javascript',
      'ts' => 'typescript',
      'tsx' => 'typescript',
      'py' => 'python',
      'sh' => 'shell',
      'yml' => 'yaml',
      'md' => 'markdown',
      _ => normalized,
    };
  }

  static List<SparkCodeToken> tokenize(
    String source, {
    required String? language,
  }) {
    final normalizedLanguage = normalizeLanguage(language);
    if (source.isEmpty) return const <SparkCodeToken>[];
    if (!supportedLanguages.contains(normalizedLanguage)) {
      return <SparkCodeToken>[SparkCodeToken(source, SparkCodeTokenKind.plain)];
    }

    final stringPattern = r'(?:(?:"""[\s\S]*?""")|'
        r"'''[\s\S]*?'''|"
        r'"(?:\\[\s\S]|[^"\\])*"|'
        r"'(?:\\[\s\S]|[^'\\])*')";
    final commentPattern = switch (normalizedLanguage) {
      'html' || 'xml' => r'<!--[\s\S]*?-->|/\*[\s\S]*?\*/',
      'python' || 'yaml' || 'shell' || 'bash' => r'#[^\r\n]*|/\*[\s\S]*?\*/',
      'sql' => r'--[^\r\n]*|/\*[\s\S]*?\*/',
      _ => r'//[^\r\n]*|/\*[\s\S]*?\*/',
    };
    final pattern = RegExp(
      '(?<string>$stringPattern)|(?<comment>$commentPattern)|'
      r'(?<number>0[xX][0-9a-fA-F]+|\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)|'
      r'(?<operator>[+\-*\/%=<>!&|^~?:]+)|'
      r'(?<word>[A-Za-z_][A-Za-z0-9_]*)',
      multiLine: true,
    );
    final keywords = _keywords[normalizedLanguage] ?? _commonKeywords;
    final booleans = _booleanWords[normalizedLanguage] ?? _commonBooleans;
    final tokens = <SparkCodeToken>[];
    var cursor = 0;

    void emit(String text, SparkCodeTokenKind kind) {
      if (text.isEmpty) return;
      if (tokens.isNotEmpty && tokens.last.kind == kind) {
        final previous = tokens.removeLast();
        tokens.add(SparkCodeToken(previous.text + text, kind));
      } else {
        tokens.add(SparkCodeToken(text, kind));
      }
    }

    for (final match in pattern.allMatches(source)) {
      if (match.start > cursor) {
        emit(source.substring(cursor, match.start), SparkCodeTokenKind.plain);
      }
      final text = match.group(0)!;
      final kind = _kindForMatch(
        match,
        source: source,
        keywords: keywords,
        booleans: booleans,
      );
      emit(text, kind);
      cursor = match.end;
    }
    if (cursor < source.length) {
      emit(source.substring(cursor), SparkCodeTokenKind.plain);
    }
    return tokens;
  }

  static SparkCodeTokenKind _kindForMatch(
    RegExpMatch match, {
    required String source,
    required Set<String> keywords,
    required Set<String> booleans,
  }) {
    if (match.namedGroup('string') != null) return SparkCodeTokenKind.string;
    if (match.namedGroup('comment') != null) return SparkCodeTokenKind.comment;
    if (match.namedGroup('number') != null) return SparkCodeTokenKind.number;
    if (match.namedGroup('operator') != null) {
      return SparkCodeTokenKind.operator;
    }

    final word = match.namedGroup('word');
    if (word == null) return SparkCodeTokenKind.plain;
    final lowerWord = word.toLowerCase();
    if (booleans.contains(lowerWord) || booleans.contains(word)) {
      return SparkCodeTokenKind.boolean;
    }
    if (keywords.contains(lowerWord) || keywords.contains(word)) {
      return SparkCodeTokenKind.keyword;
    }
    if (_nextNonWhitespaceIs(source, match.end, '(')) {
      return SparkCodeTokenKind.function;
    }
    final firstCodeUnit = word.codeUnitAt(0);
    final startsWithUppercase = firstCodeUnit >= 0x41 && firstCodeUnit <= 0x5A;
    if (_typeWords.contains(lowerWord) || startsWithUppercase) {
      return SparkCodeTokenKind.type;
    }
    if (_previousNonWhitespaceIs(source, match.start - 1, '.')) {
      return SparkCodeTokenKind.property;
    }
    return SparkCodeTokenKind.plain;
  }

  static bool _nextNonWhitespaceIs(
    String source,
    int start,
    String expected,
  ) {
    var cursor = start;
    while (cursor < source.length && _isWhitespace(source.codeUnitAt(cursor))) {
      cursor++;
    }
    return cursor < source.length && source[cursor] == expected;
  }

  static bool _previousNonWhitespaceIs(
    String source,
    int start,
    String expected,
  ) {
    var cursor = start;
    while (cursor >= 0 && _isWhitespace(source.codeUnitAt(cursor))) {
      cursor--;
    }
    return cursor >= 0 && source[cursor] == expected;
  }

  static bool _isWhitespace(int codeUnit) {
    return codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0C ||
        codeUnit == 0x0D ||
        codeUnit == 0x20;
  }

  static const _commonBooleans = <String>{
    'false',
    'null',
    'true',
  };

  static const _booleanWords = <String, Set<String>>{
    'python': {'false', 'none', 'true'},
    'yaml': {'false', 'null', 'true'},
  };

  static const _commonKeywords = <String>{
    'as',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'def',
    'do',
    'else',
    'enum',
    'extends',
    'final',
    'finally',
    'for',
    'from',
    'fun',
    'function',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'let',
    'new',
    'of',
    'override',
    'package',
    'private',
    'protected',
    'public',
    'return',
    'static',
    'switch',
    'this',
    'throw',
    'try',
    'typedef',
    'using',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };

  static const _keywords = <String, Set<String>>{
    'dart': {..._commonKeywords, 'late', 'required', 'sealed'},
    'go': {..._commonKeywords, 'chan', 'defer', 'go', 'map', 'range', 'struct'},
    'java': {..._commonKeywords, 'instanceof', 'synchronized', 'throws'},
    'javascript': {..._commonKeywords, 'delete', 'typeof'},
    'json': <String>{},
    'kotlin': {..._commonKeywords, 'data', 'object', 'suspend', 'when'},
    'python': {..._commonKeywords, 'elif', 'except', 'lambda', 'pass', 'raise'},
    'rust': {
      ..._commonKeywords,
      'crate',
      'impl',
      'match',
      'mut',
      'pub',
      'trait'
    },
    'sql': {
      'alter',
      'and',
      'as',
      'by',
      'create',
      'delete',
      'from',
      'group',
      'having',
      'insert',
      'into',
      'join',
      'limit',
      'not',
      'null',
      'on',
      'or',
      'order',
      'select',
      'set',
      'table',
      'update',
      'values',
      'where',
    },
    'swift': {..._commonKeywords, 'actor', 'guard', 'init', 'protocol'},
    'typescript': {..._commonKeywords, 'declare', 'namespace', 'readonly'},
    'yaml': <String>{},
  };

  static const _typeWords = <String>{
    'bool',
    'double',
    'dynamic',
    'float',
    'int',
    'list',
    'map',
    'num',
    'object',
    'set',
    'string',
  };
}

abstract final class SparkCodeHighlighter {
  static TextSpan textSpan(
    String source, {
    required String? language,
    required SparkCodeTheme theme,
    double? fontSize,
    double? height,
  }) {
    final tokens = SparkCodeTokenizer.tokenize(source, language: language);
    return TextSpan(
      style: theme.baseTextStyle(fontSize: fontSize, height: height),
      children: [
        for (final token in tokens)
          TextSpan(text: token.text, style: theme.styleFor(token.kind)),
      ],
    );
  }
}

class SparkCodeBlockBuilder extends MarkdownElementBuilder {
  SparkCodeBlockBuilder({required this.textStyle});

  final TextStyle? textStyle;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    md.Element? codeElement;
    for (final child
        in element.children?.whereType<md.Element>() ?? const <md.Element>[]) {
      if (child.tag == 'code') {
        codeElement = child;
        break;
      }
    }
    if (codeElement == null) return null;
    final language = codeElement.attributes['class']
        ?.replaceFirst(RegExp(r'^language-'), '');
    return SparkCodeBlock(
      code: codeElement.textContent.trimRight(),
      language: language,
      textStyle: textStyle ?? preferredStyle,
    );
  }
}

class SparkCodeBlock extends StatelessWidget {
  const SparkCodeBlock({
    super.key,
    required this.code,
    required this.language,
    required this.textStyle,
  });

  final String code;
  final String? language;
  final TextStyle? textStyle;

  Future<void> _copy() {
    return platformSparkClipboard.copyText(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SparkCodeTheme.of(context);
    final fontSize = textStyle?.fontSize ?? 13;
    final height = textStyle?.height ?? 1.45;
    final textSpan = SparkCodeHighlighter.textSpan(
      code,
      language: language,
      theme: theme,
      fontSize: fontSize,
      height: height,
    );
    final label = language == null || language!.isEmpty ? '代码' : language!;
    final codeKey = code.hashCode;
    return Container(
      key: ValueKey('paper-code-block-$codeKey'),
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.toolbarBackground,
            padding: const EdgeInsets.fromLTRB(12, 7, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: theme.comment,
                      fontSize: SparkFontSizes.caption,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('paper-code-copy-$codeKey'),
                  tooltip: '复制代码',
                  onPressed: _copy,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.copy_rounded,
                    color: theme.comment,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            key: ValueKey('paper-code-scroll-$codeKey'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SelectableText.rich(
              textSpan,
              key: ValueKey('paper-code-content-$codeKey'),
            ),
          ),
        ],
      ),
    );
  }
}
