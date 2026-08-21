import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
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
              activeColor: SparkColors.of(context).danger,
              bounceOnTap: true,
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
                color: SparkColors.of(context).card,
                surfaceTintColor: Colors.transparent,
                elevation: 8,
                shadowColor: SparkColors.of(
                  context,
                ).ink.withValues(alpha: 0.14),
                offset: const Offset(0, -4),
                constraints: const BoxConstraints.tightFor(width: 174),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    SparkDesignTokens.radiusXl,
                  ),
                ),
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: SparkColors.of(context).ink,
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
                    height: 46,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkDesignTokens.space2,
                    ),
                    child: _PaperMoreMenuItem(
                      icon: read
                          ? Icons.mark_email_unread_outlined
                          : Icons.done_all_rounded,
                      label: read ? '标记为未读' : '标记为已读',
                    ),
                  ),
                  PopupMenuItem(
                    value: _PaperMoreAction.readLater,
                    height: 46,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkDesignTokens.space2,
                    ),
                    child: _PaperMoreMenuItem(
                      icon: readLater
                          ? Icons.playlist_remove_rounded
                          : Icons.watch_later_outlined,
                      label: readLater ? '移出稍后阅读' : '加入稍后阅读',
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

class _PaperMoreMenuItem extends StatelessWidget {
  const _PaperMoreMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: SparkColors.of(context).canvas,
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
          ),
          child: Icon(icon, size: 18, color: SparkColors.of(context).ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: SparkColors.of(context).ink,
              fontSize: SparkFontSizes.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
    this.activeColor,
    this.bounceOnTap = false,
    this.onTap,
    this.onLongPress,
  });

  final String tooltip;
  final IconData icon;
  final String? label;
  final bool active;

  /// 激活态前景色；缺省用品牌 primary（点赞传 danger 呈现红心语义）。
  final Color? activeColor;

  /// 点击时先放大再弹性回落（点赞弹跳）。
  final bool bounceOnTap;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<_PaperActionButton> createState() => _PaperActionButtonState();
}

class _PaperActionButtonState extends State<_PaperActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    final color =
        widget.active ? (widget.activeColor ?? palette.primary) : palette.ink;
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
            scale: switch ((widget.bounceOnTap, _pressed)) {
              (true, true) => 1.25,
              (true, false) => 1,
              (false, true) => 0.92,
              (false, false) => 1,
            },
            duration: MotionTokens.duration(
              context,
              widget.bounceOnTap
                  ? const Duration(milliseconds: 420)
                  : MotionTokens.feedbackDuration,
            ),
            curve: widget.bounceOnTap
                ? MotionTokens.springCurve
                : MotionTokens.pageCurve,
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
                    // 计数变化时上滑滚动，避免文字生硬替换。
                    AnimatedSwitcher(
                      duration: MotionTokens.duration(
                        context,
                        MotionTokens.tabDuration,
                      ),
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                      child: Text(
                        widget.label!,
                        key: ValueKey(widget.label),
                        style: TextStyle(
                          color: color,
                          fontSize: SparkFontSizes.caption,
                          fontWeight: FontWeight.w600,
                        ),
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
