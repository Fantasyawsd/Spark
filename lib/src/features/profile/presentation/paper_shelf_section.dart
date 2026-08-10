import 'package:flutter/material.dart';

import '../../../core/theme/spark_font_sizes.dart';
import '../../../core/theme/spark_theme.dart';
import '../../../core/widgets/surface_card.dart';
import '../../papers/papers.dart';
import 'profile_section_header.dart';

class PaperShelfSection extends StatelessWidget {
  const PaperShelfSection({
    super.key,
    required this.icon,
    required this.title,
    required this.emptyText,
    required this.keyPrefix,
    required this.papers,
    required this.onOpenPaper,
    required this.onViewAll,
  });

  final IconData icon;
  final String title;
  final String emptyText;
  final String keyPrefix;
  final List<Paper> papers;
  final ValueChanged<String>? onOpenPaper;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ProfileSectionHeader(
            icon: icon,
            title: title,
            action: papers.isEmpty ? '' : '共 ${papers.length} 篇',
            onActionTap: onViewAll,
          ),
          const SizedBox(height: 14),
          if (papers.isEmpty)
            SizedBox(
              height: 72,
              child: Center(
                child: Text(
                  emptyText,
                  style: const TextStyle(
                    color: SparkColors.muted,
                    fontSize: SparkFontSizes.bodySmall,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: papers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final paper = papers[index];
                  return _ShelfPaperTile(
                    key: ValueKey('$keyPrefix-${paper.id}'),
                    paper: paper,
                    onTap: onOpenPaper == null
                        ? null
                        : () => onOpenPaper!(paper.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ShelfPaperTile extends StatelessWidget {
  const _ShelfPaperTile({
    super.key,
    required this.paper,
    required this.onTap,
  });

  final Paper paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 224,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
