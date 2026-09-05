import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_palette.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../domain/paper.dart';
import '../paper_accent.dart';
import 'paper_presenter.dart';
import 'topic_chip.dart';

class PaperGridCard extends StatefulWidget {
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
  State<PaperGridCard> createState() => _PaperGridCardState();
}

class _PaperGridCardState extends State<PaperGridCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: MotionTokens.duration(context, MotionTokens.feedbackDuration),
        curve: MotionTokens.springCurve,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(SparkDesignTokens.radius2Xl),
            border: Border.all(color: palette.line),
            boxShadow: SparkDesignTokens.interactiveShadowFor(
                Theme.of(context).brightness),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PaperGridCover(paper: widget.paper, index: widget.index),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compactAuthorLine(widget.paper),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: SparkFontSizes.caption,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    if (_badges(paper: widget.paper, palette: palette)
                        case final badges when badges.isNotEmpty)
                      Wrap(spacing: 6, runSpacing: 6, children: badges),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onLike,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Icon(
                                widget.liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: widget.liked
                                    ? palette.primary
                                    : palette.muted,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          adjustedCompactCount(
                            widget.paper.metrics.likes,
                            delta: widget.liked ? 1 : 0,
                          ),
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: SparkFontSizes.tiny,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onSave,
                          onLongPress: widget.onSaveLongPress,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Icon(
                                widget.saved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: widget.saved
                                    ? palette.primary
                                    : palette.muted,
                                size: 18,
                              ),
                            ),
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
      ),
    );
  }

  /// 徽标差异化：主题中性、Trending 琥珀火焰、「为你推荐」品牌粉。
  List<Widget> _badges({
    required Paper paper,
    required SparkPalette palette,
  }) {
    return [
      if (topicLabel(paper) case final label?)
        TopicChip(label: label, compact: true),
      if (trendLabel(paper) case final trend?)
        TopicChip(
          label: trend,
          compact: true,
          tonal: true,
          color: palette.orange,
          icon: Icons.local_fire_department_rounded,
        ),
      if (personalizationLabel(paper) case final label?)
        TopicChip(
          label: label,
          compact: true,
          tonal: true,
          color: palette.primary,
          icon: Icons.auto_awesome_rounded,
        ),
    ];
  }
}

class _PaperGridCover extends StatelessWidget {
  const _PaperGridCover({required this.paper, required this.index});

  final Paper paper;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = paper.accent.colorFor(
      isDark ? Brightness.dark : Brightness.light,
    );
    // 渐变基色按卡片表面色混合派生（暗色下 overlay alpha 上调），
    // 亮色呈现与透明渐变叠白底等价。
    final overlayTop = isDark ? 0.30 : 0.22;
    final overlayBottom = isDark ? 0.10 : 0.06;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                accent.withValues(alpha: overlayTop), palette.card),
            Color.alphaBlend(
              accent.withValues(alpha: overlayBottom),
              palette.card,
            ),
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
                    fontWeight: FontWeight.w700,
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
              height: 1.3,
              fontWeight: FontWeight.w600,
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
