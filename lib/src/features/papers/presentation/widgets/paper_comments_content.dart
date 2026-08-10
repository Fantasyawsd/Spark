import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/spark_entry_animation.dart';
import 'paper_discussion_models.dart';

class PaperCommentsContent extends StatelessWidget {
  const PaperCommentsContent({
    super.key,
    required this.comments,
    required this.expandedCommentIds,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onToggleReplies,
  });

  final List<PaperCommentData> comments;
  final Set<String> expandedCommentIds;
  final ValueChanged<String> onLike;
  final ValueChanged<String> onReply;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onToggleReplies;

  @override
  Widget build(BuildContext context) {
    final roots = comments.where((comment) => comment.parentId == null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SparkDesignTokens.space4,
          SparkDesignTokens.space1,
          SparkDesignTokens.space4,
          SparkDesignTokens.space4),
      child: Column(
        children: [
          for (final comment in roots) ...[
            SparkEntryAnimation(
              key: ValueKey(comment.id),
              child: _CommentTile(
                comment: comment,
                onLike: () => onLike(comment.id),
                onReply: () => onReply(comment.id),
                onDelete: () => onDelete(comment.id),
                onToggleReplies: () => onToggleReplies(comment.id),
              ),
            ),
            if (expandedCommentIds.contains(comment.id))
              for (final reply in comments.where(
                (item) => item.parentId == comment.id,
              ))
                Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: _CommentTile(
                    comment: reply,
                    compact: true,
                    onLike: () => onLike(reply.id),
                    onReply: () => onReply(reply.id),
                    onDelete: () => onDelete(reply.id),
                    onToggleReplies: () {},
                  ),
                ),
          ],
          if (comments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Text(
                '还没有评论，来发表第一条看法吧',
                style: TextStyle(
                    color: SparkColors.muted,
                    fontSize: SparkFontSizes.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onToggleReplies,
    this.compact = false,
  });

  final PaperCommentData comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onToggleReplies;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical:
              compact ? SparkDesignTokens.space2 : SparkDesignTokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: compact ? 15 : 19,
            backgroundColor: comment.color.withValues(alpha: 0.14),
            child: Text(
              comment.initials,
              style: TextStyle(
                color: comment.color,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.name,
                        style: const TextStyle(
                          color: SparkColors.muted,
                          fontSize: SparkFontSizes.footnote,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (comment.canDelete)
                      IconButton(
                        tooltip: '删除评论',
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: const TextStyle(
                    color: SparkColors.ink,
                    fontSize: SparkFontSizes.body,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${comment.time} · ${comment.location}',
                      style: const TextStyle(
                        color: SparkColors.subtle,
                        fontSize: SparkFontSizes.caption,
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onReply,
                      child: const Text(
                        '回复',
                        style: TextStyle(
                          color: SparkColors.muted,
                          fontSize: SparkFontSizes.caption,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            comment.liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: comment.liked
                                ? SparkColors.primary
                                : SparkColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likes}',
                            style: const TextStyle(
                              color: SparkColors.muted,
                              fontSize: SparkFontSizes.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (comment.replies > 0 && !compact) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onToggleReplies,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 1,
                          color: SparkColors.line,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '展开 ${comment.replies} 条回复',
                          style: const TextStyle(
                            color: SparkColors.muted,
                            fontSize: SparkFontSizes.caption,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: SparkColors.muted,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
