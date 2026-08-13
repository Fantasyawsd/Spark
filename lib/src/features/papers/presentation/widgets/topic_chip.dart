import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_theme.dart';

class TopicChip extends StatelessWidget {
  const TopicChip({
    super.key,
    required this.label,
    this.selected = false,
    this.compact = false,
    this.color,
  });

  final String label;
  final bool selected;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? SparkColors.of(context).primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 13,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.09)
            : SparkColors.of(context).surfaceMuted,
        borderRadius: BorderRadius.circular(SparkDesignTokens.radiusSm),
        border:
            selected ? Border.all(color: accent.withValues(alpha: 0.55)) : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? accent : SparkColors.of(context).ink,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
