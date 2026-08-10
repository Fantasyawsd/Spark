import 'package:flutter/material.dart';

import '../../../core/theme/spark_font_sizes.dart';
import '../../../core/theme/spark_theme.dart';
import '../../../core/widgets/spark_theme_sheet.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.savedCount,
    required this.readLaterCount,
    required this.historyCount,
    required this.onSavedTap,
    required this.onReadLaterTap,
    required this.onHistoryTap,
  });

  final int savedCount;
  final int readLaterCount;
  final int historyCount;
  final VoidCallback onSavedTap;
  final VoidCallback onReadLaterTap;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '我的研究库',
                style: TextStyle(
                  color: SparkColors.ink,
                  fontSize: SparkFontSizes.display,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('profile-theme-settings'),
              tooltip: '主题',
              onPressed: () => showSparkThemeSheet(context),
              icon: const Icon(Icons.palette_outlined),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '本地论文、阅读记录与 AI 配置',
          style: TextStyle(
              color: SparkColors.muted, fontSize: SparkFontSizes.bodySmall),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ProfileStat(
              value: '$savedCount',
              label: '收藏',
              onTap: onSavedTap,
            ),
            const _StatDivider(),
            _ProfileStat(
              value: '$readLaterCount',
              label: '稍后阅读',
              onTap: onReadLaterTap,
            ),
            const _StatDivider(),
            _ProfileStat(
              value: '$historyCount',
              label: '阅读历史',
              onTap: onHistoryTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: SparkColors.ink,
                    fontSize: SparkFontSizes.headlineSmall,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: SparkColors.muted,
                    fontSize: SparkFontSizes.caption,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 37,
      child: VerticalDivider(width: 1, color: SparkColors.line),
    );
  }
}
