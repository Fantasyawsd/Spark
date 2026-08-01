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
    required this.commentCountDelta,
    required this.read,
    required this.readLater,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onSaveLongPress,
    required this.onToggleRead,
    required this.onToggleReadLater,
    this.onShare,
  });

  final Paper paper;
  final bool liked;
  final bool saved;
  final int shareCountDelta;
  final int commentCountDelta;
  final bool read;
  final bool readLater;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onSaveLongPress;
  final VoidCallback onToggleRead;
  final VoidCallback onToggleReadLater;
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
              label: adjustedCompactCount(
                paper.metrics.likes,
                delta: liked ? 1 : 0,
              ),
              active: liked,
              onTap: onLike,
            ),
            _PaperActionButton(
              key: const ValueKey('paper-action-comment'),
              tooltip: '评论',
              icon: Icons.chat_bubble_outline_rounded,
              label: adjustedCompactCount(
                paper.metrics.comments,
                delta: commentCountDelta,
              ),
              onTap: onComment,
            ),
            _PaperActionButton(
              key: const ValueKey('paper-action-save'),
              tooltip: '收藏',
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: adjustedCompactCount(
                paper.metrics.saves,
                delta: saved ? 1 : 0,
              ),
              active: saved,
              onTap: onSave,
              onLongPress: onSaveLongPress,
            ),
            _PaperActionButton(
              key: const ValueKey('paper-action-share'),
              tooltip: '分享',
              icon: Icons.ios_share_outlined,
              label: adjustedCompactCount(
                paper.metrics.shares,
                delta: shareCountDelta,
              ),
              onTap: onShare,
            ),
            Expanded(
              child: PopupMenuButton<_PaperMoreAction>(
                key: const ValueKey('paper-action-more'),
                tooltip: '更多',
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: PaperFlowColors.ink,
                  size: 23,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _PaperMoreAction.read:
                      onToggleRead();
                    case _PaperMoreAction.readLater:
                      onToggleReadLater();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _PaperMoreAction.read,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        read
                            ? Icons.mark_email_unread_outlined
                            : Icons.done_all_rounded,
                      ),
                      title: Text(read ? '标记为未读' : '标记为已读'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _PaperMoreAction.readLater,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        readLater
                            ? Icons.playlist_remove_rounded
                            : Icons.watch_later_outlined,
                      ),
                      title: Text(readLater ? '移出稍后阅读' : '加入稍后阅读'),
                    ),
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

enum _PaperMoreAction { read, readLater }

class _PaperActionButton extends StatefulWidget {
  const _PaperActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.label,
    this.active = false,
    this.onTap,
    this.onLongPress,
  });

  final String tooltip;
  final IconData icon;
  final String? label;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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
          onLongPress: widget.onLongPress,
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
