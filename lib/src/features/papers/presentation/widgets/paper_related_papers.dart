import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/topic_chip.dart';
import '../../domain/paper.dart';

class PaperRelatedPapers extends StatelessWidget {
  const PaperRelatedPapers({
    super.key,
    required this.papers,
    required this.topics,
    required this.onOpen,
  });

  final List<RelatedPaper> papers;
  final List<String> topics;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        if (papers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 44),
            child: Center(
              child: Text(
                '暂时没有相关论文',
                style: TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          for (var index = 0; index < papers.length; index++) ...[
            _RelatedPaperRow(
              paper: papers[index],
              onOpen: onOpen == null ? null : () => onOpen!(papers[index].id),
            ),
            if (index != papers.length - 1)
              const Divider(height: 1, color: PaperFlowColors.line),
          ],
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final topic in topics)
                TopicChip(label: topic, compact: true),
            ],
          ),
        ],
      ],
    );
  }
}

class _RelatedPaperRow extends StatelessWidget {
  const _RelatedPaperRow({required this.paper, required this.onOpen});

  final RelatedPaper paper;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('related-paper-${paper.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PaperFlowColors.ink,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    paper.venue == null
                        ? paper.relation
                        : '${paper.venue} · ${paper.relation}',
                    style: const TextStyle(
                      color: PaperFlowColors.muted,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: PaperFlowColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
