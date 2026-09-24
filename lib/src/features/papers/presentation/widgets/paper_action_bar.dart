import 'package:flutter/material.dart';

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
    this.onAnalyze,
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
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Tooltip(
              message: saved ? '取消收藏；长按选择分组' : '收藏；长按选择分组',
              triggerMode: TooltipTriggerMode.manual,
              child: GestureDetector(
                onLongPress: onSaveLongPress,
                child: IconButton(
                  key: const ValueKey('paper-action-save'),
                  onPressed: onSave,
                  color: saved ? palette.primary : palette.muted,
                  icon: Icon(saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('paper-action-read-later'),
              tooltip: readLater ? '移出稍后阅读' : '加入稍后阅读',
              onPressed: onToggleReadLater,
              color: readLater ? palette.primary : palette.muted,
              icon: Icon(
                  readLater ? Icons.watch_later : Icons.watch_later_outlined),
            ),
            const SizedBox(width: 4),
            if (onAnalyze != null)
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('paper-ai-entry'),
                  onPressed: onAnalyze,
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('ChatPaper',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              )
            else
              const Spacer(),
            PopupMenuButton<_PaperMoreAction>(
              key: const ValueKey('paper-action-more'),
              tooltip: '更多',
              icon: Icon(Icons.more_horiz_rounded, color: palette.muted),
              onSelected: (action) {
                switch (action) {
                  case _PaperMoreAction.like:
                    onLike();
                  case _PaperMoreAction.comment:
                    onComment();
                  case _PaperMoreAction.share:
                    onShare?.call();
                  case _PaperMoreAction.read:
                    onToggleRead();
                  case _PaperMoreAction.readLater:
                    onToggleReadLater();
                  case _PaperMoreAction.group:
                    onSaveLongPress();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: const ValueKey('paper-action-like'),
                  value: _PaperMoreAction.like,
                  child: _menuItem(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      '${liked ? '取消点赞' : '点赞'} · ${adjustedCompactCount(paper.metrics.likes, delta: liked ? 1 : 0)}'),
                ),
                PopupMenuItem(
                  key: const ValueKey('paper-action-comment'),
                  value: _PaperMoreAction.comment,
                  child: _menuItem(Icons.chat_bubble_outline_rounded,
                      '评论 · ${adjustedCompactCount(paper.metrics.comments, delta: commentCountDelta)}'),
                ),
                PopupMenuItem(
                  key: const ValueKey('paper-action-share'),
                  value: _PaperMoreAction.share,
                  enabled: onShare != null,
                  child: _menuItem(Icons.ios_share_outlined,
                      '分享 · ${adjustedCompactCount(paper.metrics.shares, delta: shareCountDelta)}'),
                ),
                PopupMenuItem(
                  value: _PaperMoreAction.group,
                  child: _menuItem(Icons.folder_outlined, '收藏分组'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _PaperMoreAction.read,
                  child: _menuItem(
                      Icons.done_all_rounded, read ? '标记为未读' : '标记为已读'),
                ),
                PopupMenuItem(
                  value: _PaperMoreAction.readLater,
                  child: _menuItem(Icons.watch_later_outlined,
                      readLater ? '移出稍后阅读' : '加入稍后阅读'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Flexible(child: Text(label)),
    ]);
  }
}

enum _PaperMoreAction { like, comment, share, read, readLater, group }
