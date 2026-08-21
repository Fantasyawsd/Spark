import 'package:flutter/material.dart';

import '../theme/spark_design_tokens.dart';
import '../theme/spark_font_sizes.dart';
import '../theme/spark_theme.dart';

/// 统一空状态：彩底圆形图标 + 主文案 + 副文案 + 可选引导动作。
///
/// 替换各模块散落的「灰图标 + 单行文字」空态。
class SparkEmptyState extends StatelessWidget {
  const SparkEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkDesignTokens.space6,
        vertical: SparkDesignTokens.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: palette.muted),
          ),
          const SizedBox(height: SparkDesignTokens.space3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.ink,
              fontSize: SparkFontSizes.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.muted,
                fontSize: SparkFontSizes.footnote,
                height: 1.5,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SparkDesignTokens.space4),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
