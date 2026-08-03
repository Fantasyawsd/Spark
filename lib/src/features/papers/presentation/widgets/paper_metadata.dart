import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../domain/paper.dart';
import 'paper_presenter.dart';

class PaperMetadata extends StatelessWidget {
  const PaperMetadata({
    super.key,
    required this.paper,
    required this.followed,
    required this.onFollow,
  });

  final Paper paper;
  final bool followed;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final year = paper.publishedAt?.year;
    final citations = citationLine(paper);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                compactAuthorLine(paper),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: ValueKey('paper-follow-${paper.id}'),
              onPressed: onFollow,
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    followed ? PaperFlowColors.primary : PaperFlowColors.ink,
                side: BorderSide(
                  color: followed
                      ? PaperFlowColors.primary.withValues(alpha: 0.4)
                      : PaperFlowColors.line,
                ),
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(
                followed
                    ? Icons.person_remove_outlined
                    : Icons.person_add_alt_1_outlined,
                size: 15,
              ),
              label: Text(
                followed ? '已关注' : '关注作者',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 12,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              venueLabel(paper),
              style: const TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (year != null)
              Text(
                '$year 年发布',
                style: const TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (citations != null)
              Text(
                citations,
                style: const TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
