import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../paper_ai_ui_tokens.dart';

class PaperAiMessageSelectionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PaperAiMessageSelectionAppBar({
    super.key,
    required this.count,
    required this.onCancel,
  });

  final int count;
  final VoidCallback onCancel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        key: const ValueKey('paper-ai-selection-cancel'),
        tooltip: '取消选择',
        onPressed: onCancel,
        icon: const Icon(Icons.close_rounded),
      ),
      backgroundColor: PaperAiUiTokens.canvas(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 8,
      title: Text(
        '选择消息',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: SparkFontSizes.title,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '$count 条',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: SparkFontSizes.footnote,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PaperAiMessageSelectionBar extends StatelessWidget {
  const PaperAiMessageSelectionBar({
    super.key,
    required this.count,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: PaperAiUiTokens.composer(context),
            borderRadius: BorderRadius.circular(SparkDesignTokens.radius3Xl),
            border: Border.all(color: PaperAiUiTokens.composerBorder(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '已选择 $count 条消息',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: SparkFontSizes.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('paper-ai-selection-cancel-button'),
                onPressed: onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                key: const ValueKey('paper-ai-selection-delete'),
                onPressed: count == 0 ? null : onDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  minimumSize: const Size(88, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('删除'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
