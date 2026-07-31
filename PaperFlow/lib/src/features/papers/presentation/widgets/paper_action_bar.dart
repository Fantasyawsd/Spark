import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/paperflow_theme.dart';
import '../../domain/paper.dart';
import 'paper_presenter.dart';

class PaperActionBar extends StatelessWidget {
  const PaperActionBar({
    super.key,
    required this.paper,
    required this.liked,
    required this.saved,
    required this.shareCountDelta,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    this.onShare,
  });

  final PaperRecord paper;
  final bool liked;
  final bool saved;
  final int shareCountDelta;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            _PaperActionButton(
              tooltip: '点赞',
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: adjustedCompactCount(paper.likes, delta: liked ? 1 : 0),
              active: liked,
              onTap: onLike,
            ),
            _PaperActionButton(
              tooltip: '评论',
              icon: Icons.chat_bubble_outline_rounded,
              label: adjustedCompactCount(paper.comments),
              onTap: onComment,
            ),
            _PaperActionButton(
              tooltip: '收藏',
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: adjustedCompactCount(paper.saves, delta: saved ? 1 : 0),
              active: saved,
              onTap: onSave,
            ),
            _PaperActionButton(
              key: const ValueKey('paper-action-share'),
              tooltip: '分享',
              icon: Icons.ios_share_outlined,
              label: adjustedCompactCount(
                paper.shares,
                delta: shareCountDelta,
              ),
              onTap: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperActionButton extends StatefulWidget {
  const _PaperActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.label,
    this.active = false,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final String? label;
  final bool active;
  final VoidCallback? onTap;

  @override
  State<_PaperActionButton> createState() => _PaperActionButtonState();
}

class _PaperActionButtonState extends State<_PaperActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? PaperFlowColors.primary : PaperFlowColors.ink;
    return Expanded(
      child: Tooltip(
        message: widget.tooltip,
        child: InkResponse(
          onTap: widget.onTap == null
              ? null
              : () {
                  setState(() => _pressed = true);
                  widget.onTap!();
                  Future<void>.delayed(MotionTokens.feedbackDuration, () {
                    if (mounted) setState(() => _pressed = false);
                  });
                },
          radius: 28,
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: MotionTokens.duration(
              context,
              MotionTokens.feedbackDuration,
            ),
            curve: MotionTokens.pageCurve,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: MotionTokens.duration(
                      context,
                      MotionTokens.feedbackDuration,
                    ),
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.icon),
                      color: color,
                      size: 23,
                    ),
                  ),
                  if (widget.label != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.label!,
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
