import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../papers/papers.dart';

/// 「我的」页横向滚动列表中的论文小卡：3 行标题 + 单行 venue。
/// 收藏分组与书架（稍后阅读/阅读历史）共用。
class PaperMiniCard extends StatelessWidget {
  const PaperMiniCard({super.key, required this.paper, this.onTap});

  final Paper paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
      child: Container(
        width: 224,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
          border: Border.all(color: SparkColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paper.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SparkColors.ink,
                fontSize: SparkFontSizes.bodySmall,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              paper.venue ??
                  paper.journalReference ??
                  (paper.source == 'arxiv' ? 'arXiv' : paper.source),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SparkColors.muted,
                fontSize: SparkFontSizes.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
