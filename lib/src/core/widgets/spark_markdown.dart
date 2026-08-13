import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/spark_font_sizes.dart';
import '../theme/spark_theme.dart';
import 'spark_code_highlight.dart';
import 'spark_markdown_latex.dart';
import 'spark_markdown_processing.dart';

export 'spark_markdown_latex.dart';
export 'spark_markdown_processing.dart';

/// The single Markdown rendering path used by paper content and AI output.
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
    final content = MarkdownBody(
      data: markdown,
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

    if (!selectable) return SelectionContainer.disabled(child: content);
    if (SelectionContainer.maybeOf(context) != null) return content;
    return SelectionArea(child: content);
  }
}

/// Reading body measurement style. Color is applied by the theme-specific style.
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
