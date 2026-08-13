import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Inline LaTeX syntax that closes at the nearest unescaped delimiter.
class SparkLatexInlineSyntax extends md.InlineSyntax {
  SparkLatexInlineSyntax() : super(_patternSource);

  static final String _patternSource = r'\$\$(?:\\[\s\S]|[^$\n])*?\$\$'
      r'|\$(?:\\[\s\S]|[^$\n])*?\$'
      r'|\\\[(?:\\[\s\S]|[^\\\n])*?\\\]'
      r'|\\\((?:\\[\s\S]|[^\\\n])*?\\\)';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final raw = match.group(0) ?? '';
    final (equation, mathStyle) = _equationAndStyle(raw);
    if (equation == null || mathStyle == null) {
      parser.addNode(md.Text(raw));
      return true;
    }
    final element = md.Element.text('latex', equation);
    element.attributes['MathStyle'] = mathStyle;
    parser.addNode(element);
    return true;
  }

  static (String?, String?) _equationAndStyle(String raw) {
    if (raw.startsWith(r'$$') && raw.endsWith(r'$$') && raw.length >= 4) {
      return (raw.substring(2, raw.length - 2), 'display');
    }
    if (raw.startsWith(r'\[') && raw.endsWith(r'\]') && raw.length >= 4) {
      return (raw.substring(2, raw.length - 2), 'display');
    }
    if (raw.startsWith(r'\(') && raw.endsWith(r'\)') && raw.length >= 4) {
      return (raw.substring(2, raw.length - 2), 'text');
    }
    if (raw.startsWith(r'$') && raw.endsWith(r'$') && raw.length >= 2) {
      return (raw.substring(1, raw.length - 1), 'text');
    }
    return (null, null);
  }
}

/// Renders formulas inline so surrounding Markdown text keeps its paragraph flow.
class SparkLatexElementBuilder extends MarkdownElementBuilder {
  SparkLatexElementBuilder({this.textStyle, this.textScaleFactor});

  final TextStyle? textStyle;
  final double? textScaleFactor;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    if (text.isEmpty) return const Text('');
    final mathStyle = element.attributes['MathStyle'] == 'display'
        ? MathStyle.display
        : MathStyle.text;
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
