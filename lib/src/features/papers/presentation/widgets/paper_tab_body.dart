import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/spark_markdown.dart';
import 'topic_chip.dart';

class PaperTabBody extends StatelessWidget {
  const PaperTabBody({
    super.key,
    required this.text,
    required this.expandable,
    this.topics = const [],
    this.stabilizeGeneratedSyntax = false,
    this.bottomLeadingAction,
    required this.onExpand,
  });

  final String text;
  final bool expandable;
  final List<String> topics;
  final bool stabilizeGeneratedSyntax;
  final Widget? bottomLeadingAction;
  final VoidCallback onExpand;

  static const textStyle = paperReaderBodyTextStyle;
  static const bottomActionHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              key: const ValueKey('paper-tab-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SparkMarkdown(
                    data: text,
                    styleSheet: paperReaderMarkdownStyle(context),
                    stabilizeGeneratedSyntax: stabilizeGeneratedSyntax,
                  ),
                  if (topics.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final topic in topics) TopicChip(label: topic)
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (expandable || bottomLeadingAction != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (bottomLeadingAction != null) bottomLeadingAction!,
                if (expandable)
                  TextButton.icon(
                    onPressed: onExpand,
                    icon: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: const Text('展开全文'),
                    style: TextButton.styleFrom(
                      foregroundColor: SparkColors.of(context).primary,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: SparkDesignTokens.space2),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
