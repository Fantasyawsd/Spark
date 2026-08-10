import 'package:flutter/material.dart';

import '../../../core/theme/spark_design_tokens.dart';
import '../../../core/theme/spark_font_sizes.dart';
import '../../../core/theme/spark_theme.dart';

class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.action = '查看全部',
    this.onActionTap,
  });

  final IconData icon;
  final String title;
  final String action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: SparkColors.muted, size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: SparkColors.ink,
              fontSize: SparkFontSizes.titleSmall,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action.isNotEmpty)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      color: SparkColors.muted,
                      fontSize: SparkFontSizes.caption,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: SparkColors.muted,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
