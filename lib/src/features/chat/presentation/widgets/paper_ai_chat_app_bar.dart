import 'package:flutter/material.dart';

import '../../../../core/diagnostics/diagnostics.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../domain/chat_context.dart';
import '../paper_ai_ui_tokens.dart';
import 'paper_ai_message_selection_bar.dart';

class PaperAiChatAppBar extends StatefulWidget implements PreferredSizeWidget {
  const PaperAiChatAppBar({
    super.key,
    required this.initialTitle,
    required this.subtitle,
    required this.previewMode,
    required this.onPreviewModeChanged,
    required this.onOpenSettings,
    required this.onApplyFullText,
    required this.selectionActive,
    required this.selectionCount,
    required this.onCancelSelection,
    this.fullTextAvailable = false,
    this.onLoadFullText,
  });

  final String initialTitle;
  final String subtitle;
  final bool previewMode;
  final ValueChanged<bool> onPreviewModeChanged;
  final VoidCallback onOpenSettings;
  final bool Function(ChatContext context) onApplyFullText;
  final bool selectionActive;
  final int selectionCount;
  final VoidCallback onCancelSelection;
  final bool fullTextAvailable;
  final Future<ChatContext> Function()? onLoadFullText;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<PaperAiChatAppBar> createState() => _PaperAiChatAppBarState();
}

class _PaperAiChatAppBarState extends State<PaperAiChatAppBar> {
  late String _title;
  bool _fullTextEnabled = false;
  bool _fullTextLoading = false;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectionActive) {
      return PaperAiMessageSelectionAppBar(
        count: widget.selectionCount,
        onCancel: widget.onCancelSelection,
      );
    }
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        key: const ValueKey('paper-ai-back'),
        tooltip: '返回',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      backgroundColor: PaperAiUiTokens.canvas(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 8,
      title: _buildTitle(context),
      actions: _buildActions(),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Semantics(
      button: true,
      label: '编辑会话标题',
      child: GestureDetector(
        key: const ValueKey('paper-ai-title'),
        onTap: _editTitle,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: SparkFontSizes.title,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.64,
              child: Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: SparkFontSizes.caption,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      if (widget.fullTextAvailable)
        IconButton(
          key: const ValueKey('paper-ai-fulltext-toggle'),
          tooltip: _fullTextEnabled ? '已读取全文' : '读取论文全文',
          onPressed: _fullTextLoading ? null : _toggleFullText,
          icon: _fullTextLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _fullTextEnabled
                      ? Icons.menu_book_rounded
                      : Icons.menu_book_outlined,
                  size: 24,
                ),
        ),
      IconButton(
        key: const ValueKey('paper-ai-session-settings'),
        tooltip: '会话设置',
        onPressed: widget.onOpenSettings,
        icon: const Icon(Icons.tune_rounded, size: 24),
      ),
      IconButton(
        key: const ValueKey('paper-ai-outline-toggle'),
        tooltip: widget.previewMode ? '返回聊天' : '查看对话大纲',
        onPressed: () => widget.onPreviewModeChanged(!widget.previewMode),
        icon: Icon(
          widget.previewMode
              ? Icons.close_rounded
              : Icons.format_list_bulleted_rounded,
          size: 24,
        ),
      ),
      const SizedBox(width: 4),
    ];
  }

  Future<void> _editTitle() async {
    var editedTitle = _title;
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑会话标题'),
        content: TextFormField(
          key: const ValueKey('paper-ai-title-input'),
          initialValue: editedTitle,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          onChanged: (value) => editedTitle = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(hintText: '输入会话标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editedTitle),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final normalized = nextTitle?.trim();
    if (normalized != null && normalized.isNotEmpty && mounted) {
      setState(() => _title = normalized);
    }
  }

  Future<void> _toggleFullText() async {
    if (_fullTextLoading || _fullTextEnabled) return;
    final loader = widget.onLoadFullText;
    if (loader == null) return;
    setState(() => _fullTextLoading = true);
    String? errorMessage;
    try {
      final nextContext = await loader();
      if (!mounted) return;
      if (widget.onApplyFullText(nextContext)) {
        _fullTextEnabled = true;
      } else {
        errorMessage = '全文上下文与当前会话不匹配，请重试。';
      }
    } on Object catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.chatLoadFullText,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
      errorMessage = '无法读取论文全文，请稍后重试。';
    } finally {
      if (mounted) setState(() => _fullTextLoading = false);
    }
    if (mounted && errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }
}
