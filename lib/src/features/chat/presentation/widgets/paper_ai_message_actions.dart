import 'package:flutter/material.dart';

import '../../../../core/platform/spark_clipboard.dart';
import '../../../../core/theme/spark_design_tokens.dart';
import '../../domain/chat_message.dart';
import '../paper_ai_ui_tokens.dart';

class PaperAiMessageActionRow extends StatelessWidget {
  const PaperAiMessageActionRow({
    super.key,
    required this.message,
    required this.assistant,
    this.onRetry,
    this.onEdit,
    this.onDelete,
  });

  final ChatMessage message;
  final bool assistant;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MessageActionButton(
            key: ValueKey(
              assistant ? 'paper-ai-assistant-copy' : 'paper-ai-user-copy',
            ),
            tooltip: '复制',
            icon: Icons.copy_all_outlined,
            onPressed: () => _copy(context),
          ),
          if (assistant && onRetry != null)
            _MessageActionButton(
              key: const ValueKey('paper-ai-assistant-retry'),
              tooltip: '重新生成',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          if (!assistant && onEdit != null)
            _MessageActionButton(
              key: const ValueKey('paper-ai-user-edit'),
              tooltip: '修改',
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
          if (assistant && onDelete != null)
            _MessageActionButton(
              key: const ValueKey('paper-ai-assistant-more'),
              tooltip: '更多',
              icon: Icons.more_vert_rounded,
              onPressed: () => _showMore(context),
            ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    // COT/reasoning is an internal trace and must never enter the clipboard.
    final text = message.content;
    if (text.trim().isEmpty) return;
    await platformSparkClipboard.copyText(text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制消息')),
      );
    }
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PaperAiUiTokens.canvas(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkDesignTokens.radius3Xl),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('删除消息'),
              onTap: onDelete == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onDelete!();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 20,
        color: onPressed == null
            ? PaperAiUiTokens.actionMuted(context)
            : PaperAiUiTokens.action(context),
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        maximumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
