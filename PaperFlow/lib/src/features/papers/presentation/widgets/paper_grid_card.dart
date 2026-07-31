import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/topic_chip.dart';
import '../../domain/paper.dart';
import '../paper_accent.dart';
import 'paper_presenter.dart';

class PaperGridCard extends StatelessWidget {
  const PaperGridCard({
    super.key,
    required this.paper,
    required this.index,
    required this.liked,
    required this.saved,
    required this.onOpen,
    required this.onLike,
    required this.onSave,
  });

  final PaperRecord paper;
  final int index;
  final bool liked;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: PaperFlowColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F15213A),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PaperGridCover(paper: paper, index: index),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    compactAuthorLine(paper),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PaperFlowColors.muted,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 9),
                  TopicChip(label: paper.topics.first, compact: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onLike,
                        child: Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: liked
                              ? PaperFlowColors.primary
                              : PaperFlowColors.muted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        adjustedCompactCount(
                          paper.likes,
                          delta: liked ? 1 : 0,
                        ),
                        style: const TextStyle(
                          color: PaperFlowColors.muted,
                          fontSize: 9.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onSave,
                        child: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: saved
                              ? PaperFlowColors.primary
                              : PaperFlowColors.muted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperGridCover extends StatelessWidget {
  const _PaperGridCover({required this.paper, required this.index});

  final PaperRecord paper;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = paper.accent.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded, color: accent, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  paper.venue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: index.isEven ? 16 : 24),
          Text(
            paper.title,
            maxLines: index.isEven ? 4 : 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PaperFlowColors.ink,
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(
                Icons.format_quote_rounded,
                color: PaperFlowColors.muted,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '被引 ${paper.citations}',
                style: const TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
