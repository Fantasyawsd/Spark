import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/paperflow_theme.dart';
import '../../domain/paper.dart';

class PaperActionBar extends StatelessWidget {
  const PaperActionBar({
    super.key,
    required this.paper,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    this.onShare,
    this.onAnalyze,
  });

  final PaperRecord paper;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback? onShare;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            _PaperActionButton(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: paper.likes,
              active: liked,
              onTap: onLike,
            ),
            _PaperActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: paper.comments,
              onTap: onComment,
            ),
            _PaperActionButton(
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: paper.saves,
              active: saved,
              onTap: onSave,
            ),
            _PaperActionButton(
              icon: Icons.reply_rounded,
              label: paper.shares,
              onTap: onShare,
            ),
            if (onAnalyze != null)
              _PaperActionButton(
                icon: Icons.auto_awesome_outlined,
                label: 'AI',
                onTap: onAnalyze,
              ),
          ],
        ),
      ),
    );
  }
}

class _PaperActionButton extends StatefulWidget {
  const _PaperActionButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
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
          child: Row(
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
