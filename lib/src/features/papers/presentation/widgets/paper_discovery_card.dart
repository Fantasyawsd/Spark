import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../domain/paper.dart';
import 'paper_presenter.dart';

/// A data-only preview. Opening discovery never requests AI-generated content.
class PaperDiscoveryCard extends StatelessWidget {
  const PaperDiscoveryCard({
    super.key,
    required this.paper,
    required this.saved,
    required this.readLater,
    required this.onOpen,
    required this.onSave,
    required this.onSaveLongPress,
    required this.onReadLater,
  });

  final Paper paper;
  final bool saved;
  final bool readLater;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveLongPress;
  final VoidCallback onReadLater;

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    // Discovery uses the original abstract. Chinese translations are managed
    // separately by the reader and must never be inferred from placeholders.
    final preview = paper.content.originalAbstractMarkdown;
    final topic = topicLabel(paper);
    final trend = trendLabel(paper);
    final personalized = personalizationLabel(paper);
    final published = paper.publishedAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusCard),
          side: BorderSide(color: palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 480;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey('paper-discovery-scroll-${paper.id}'),
                    padding: EdgeInsets.fromLTRB(20, compact ? 12 : 24, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  [
                                    venueLabel(paper),
                                    if (published != null)
                                      '${published.year}.${published.month.toString().padLeft(2, '0')}.${published.day.toString().padLeft(2, '0')}',
                                  ].join(' · '),
                                  style: TextStyle(
                                      color: palette.muted, fontSize: 12)),
                            ),
                            Tooltip(
                              message: saved ? '取消收藏' : '收藏',
                              triggerMode: TooltipTriggerMode.manual,
                              child: GestureDetector(
                                onLongPress: onSaveLongPress,
                                child: IconButton(
                                  key: ValueKey(
                                      'paper-discovery-save-${paper.id}'),
                                  onPressed: onSave,
                                  icon: Icon(saved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded),
                                  color:
                                      saved ? palette.primary : palette.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(paper.title,
                            key: ValueKey('paper-discovery-title-${paper.id}'),
                            style: SparkTheme.editorialTitle(context,
                                size: compact ? 24 : 28)),
                        const SizedBox(height: 12),
                        Text(compactAuthorLine(paper),
                            style: TextStyle(
                                color: palette.muted,
                                fontSize: 13,
                                height: 1.5)),
                        if (topic != null ||
                            trend != null ||
                            personalized != null) ...[
                          const SizedBox(height: 16),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final label in [topic, trend, personalized])
                              if (label != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: label == topic
                                        ? palette.surfaceMuted
                                        : palette.primaryPale,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(label,
                                      style: TextStyle(
                                          color: label == topic
                                              ? palette.muted
                                              : palette.primary,
                                          fontSize: 12)),
                                ),
                          ]),
                        ],
                        const SizedBox(height: 24),
                        Text('ABSTRACT',
                            style: TextStyle(
                                color: palette.primary,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Text(preview,
                            maxLines: compact ? 4 : 7,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: palette.ink, fontSize: 16, height: 1.8)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: ValueKey('paper-discovery-open-${paper.id}'),
                          onPressed: onOpen,
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text('开始阅读'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        key: ValueKey('paper-discovery-later-${paper.id}'),
                        tooltip: readLater ? '移出稍后阅读' : '加入稍后阅读',
                        onPressed: onReadLater,
                        color: readLater ? palette.primary : palette.muted,
                        icon: Icon(readLater
                            ? Icons.watch_later
                            : Icons.watch_later_outlined),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
