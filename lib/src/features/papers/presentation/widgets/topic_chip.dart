import 'package:flutter/material.dart';

import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';

class TopicChip extends StatelessWidget {
  const TopicChip({
    super.key,
    required this.label,
    this.selected = false,
    this.compact = false,
    this.color,
    this.icon,
    this.tonal = false,
  });

  final String label;
  final bool selected;
  final bool compact;

  /// 语义色：selected / tonal 时作为前景与容器染色。
  final Color? color;

  /// 前置小图标（如 Trending 火焰、个性化 ✦）。
  final IconData? icon;

  /// 彩色调性模式：accent 染色底 + accent 前景，用于徽标差异化。
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    final accent = color ?? palette.primary;
    final highlighted = selected || tonal;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 13,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? accent.withValues(alpha: tonal ? 0.12 : 0.09)
            : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border:
            selected ? Border.all(color: accent.withValues(alpha: 0.55)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: highlighted ? accent : palette.muted),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlighted ? accent : palette.ink,
              fontSize:
                  compact ? SparkFontSizes.caption : SparkFontSizes.footnote,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
