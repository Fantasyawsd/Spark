import 'package:flutter/material.dart';

import '../../../core/theme/spark_font_sizes.dart';
import '../../../core/theme/spark_theme.dart';
import '../../../core/widgets/surface_card.dart';
import '../../papers/papers.dart';
import 'profile_section_header.dart';
import 'widgets/paper_mini_card.dart';

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
                  style: TextStyle(
                    color: SparkColors.of(context).muted,
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
                  return PaperMiniCard(
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
