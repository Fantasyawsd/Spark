import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/topic_chip.dart';
import '../../domain/paper.dart';
import '../paper_accent.dart';
import 'paper_presenter.dart';

class PaperGridCard extends StatelessWidget {
  const PaperGridCard({
    super.key,
    required this.paper,
    required this.index,
    required this.liked,
    required this.saved,
    required this.onOpen,
    required this.onLike,
    required this.onSave,
    required this.onSaveLongPress,
  });

  final Paper paper;
  final int index;
  final bool liked;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onSaveLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radius2Xl),
          border: Border.all(color: SparkColors.of(context).line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F15213A),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PaperGridCover(paper: paper, index: index),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    compactAuthorLine(paper),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SparkColors.of(context).muted,
                      fontSize: SparkFontSizes.caption,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 9),
                  if (topicLabel(paper) case final label?)
                    TopicChip(label: label, compact: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onLike,
                        child: Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: liked
                              ? SparkColors.of(context).primary
                              : SparkColors.of(context).muted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        adjustedCompactCount(
                          paper.metrics.likes,
                          delta: liked ? 1 : 0,
                        ),
                        style: TextStyle(
                          color: SparkColors.of(context).muted,
                          fontSize: SparkFontSizes.tiny,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onSave,
                        onLongPress: onSaveLongPress,
                        child: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: saved
                              ? SparkColors.of(context).primary
                              : SparkColors.of(context).muted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperGridCover extends StatelessWidget {
  const _PaperGridCover({required this.paper, required this.index});

  final Paper paper;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = paper.accent.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded, color: accent, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  venueLabel(paper),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: SparkFontSizes.tiny,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: index.isEven ? 16 : 24),
          Text(
            paper.title,
            maxLines: index.isEven ? 4 : 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: SparkColors.of(context).ink,
              fontSize: SparkFontSizes.bodyLarge,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          if (citationLine(paper) case final citations?)
            Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: SparkColors.of(context).muted,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  citations,
                  style: TextStyle(
                    color: SparkColors.of(context).muted,
                    fontSize: SparkFontSizes.tiny,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
