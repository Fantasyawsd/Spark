/// Markdown text processing kept independent from Flutter widget rendering.
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
      if (marker[0] != fenceCharacter ||
          marker.length < fenceLength ||
          trailing.trim().isNotEmpty) {
        continue;
      }
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
    if (RegExp(r'[\\^_={}+*/]|[A-Za-z]\s*\(').hasMatch(fragment)) {
      pending.add(_PendingCloser(opening, r'$'));
    }
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
