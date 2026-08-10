import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/spark_markdown.dart';
import '../../../../core/widgets/topic_chip.dart';

class PaperTabBody extends StatelessWidget {
  const PaperTabBody({
    super.key,
    required this.text,
    required this.expandable,
    this.topics = const [],
    this.stabilizeGeneratedSyntax = false,
    required this.onExpand,
  });

  final String text;
  final bool expandable;
  final List<String> topics;
  final bool stabilizeGeneratedSyntax;
  final VoidCallback onExpand;

  static const textStyle = paperReaderBodyTextStyle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: _plainText(text), style: textStyle),
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final hasOverflow = expandable &&
            painter.height >
                (constraints.maxHeight - _CollapsedPaperContent.actionHeight);

        if (expandable && !hasOverflow) {
          return _StaticPaperContent(
            markdown: text,
            stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
          );
        }

        if (!expandable) {
          return _ScrollablePaperContent(
            key: const ValueKey('paper-tab-scroll'),
            markdown: text,
            topics: topics,
            stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
          );
        }

        return _CollapsedPaperContent(
          text: text,
          stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
          onExpand: onExpand,
        );
      },
    );
  }

  static String _plainText(String markdown) {
    return markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' code ')
        .replaceAllMapped(
          RegExp(r'`([^`]*)`'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]*\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'^[#>*+\-]+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'[*_~$]'), '');
  }
}

class _CollapsedPaperContent extends StatelessWidget {
  const _CollapsedPaperContent({
    required this.text,
    required this.stabilizeGeneratedSyntax,
    required this.onExpand,
  });

  static const actionHeight = 36.0;
  static const fadeHeight = 40.0;

  final String text;
  final bool stabilizeGeneratedSyntax;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: SparkMarkdown(
                      data: text,
                      styleSheet: paperReaderMarkdownStyle(),
                      stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: fadeHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          SparkColors.card.withValues(alpha: 0),
                          SparkColors.card,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onExpand,
            style: TextButton.styleFrom(
              foregroundColor: SparkColors.ink,
              padding: const EdgeInsets.symmetric(
                  horizontal: SparkDesignTokens.space1),
              minimumSize: const Size(0, actionHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            label: const Text(
              '展开全文',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaticPaperContent extends StatelessWidget {
  const _StaticPaperContent({
    required this.markdown,
    required this.stabilizeGeneratedSyntax,
  });

  final String markdown;
  final bool stabilizeGeneratedSyntax;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SparkMarkdown(
        data: markdown,
        styleSheet: paperReaderMarkdownStyle(),
        stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
      ),
    );
  }
}

class _ScrollablePaperContent extends StatelessWidget {
  const _ScrollablePaperContent({
    super.key,
    required this.markdown,
    required this.topics,
    required this.stabilizeGeneratedSyntax,
  });

  final String markdown;
  final List<String> topics;
  final bool stabilizeGeneratedSyntax;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: SparkDesignTokens.space3),
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SparkMarkdown(
            data: markdown,
            styleSheet: paperReaderMarkdownStyle(),
            stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
          ),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final topic in topics)
                  TopicChip(label: topic, compact: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
