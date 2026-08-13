import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../domain/chat_ai_service.dart';
import '../paper_ai_ui_tokens.dart';
import 'paper_ai_model_avatar.dart';
import 'paper_ai_composer_sheets.dart';

class PaperAiComposer extends StatefulWidget {
  const PaperAiComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.reasoningEffort,
    required this.onReasoningEffortChanged,
    required this.webSearchAvailable,
    required this.webSearchEnabled,
    required this.onWebSearchChanged,
    required this.hasContext,
    required this.onClearContext,
    required this.onChanged,
    required this.onSend,
    required this.onCancel,
    this.focusNode,
    this.modelName = 'deepseek-v4-flash',
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final ChatReasoningEffort reasoningEffort;
  final ValueChanged<ChatReasoningEffort> onReasoningEffortChanged;
  final bool webSearchAvailable;
  final bool webSearchEnabled;
  final ValueChanged<bool> onWebSearchChanged;
  final bool hasContext;
  final VoidCallback onClearContext;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final FocusNode? focusNode;
  final String modelName;

  @override
  State<PaperAiComposer> createState() => _PaperAiComposerState();
}

class _PaperAiComposerState extends State<PaperAiComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant PaperAiComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && widget.controller.text.trim().isNotEmpty;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  key: const ValueKey('paper-ai-composer-toolbar'),
                  height: 38,
                  child: Row(
                    children: [
                      _ToolbarAvatarButton(
                        key: const ValueKey('paper-ai-model-setting'),
                        tooltip: '选择模型',
                        onTap: widget.enabled
                            ? () => showPaperAiModelSheet(
                                  context,
                                  modelName: widget.modelName,
                                )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _ToolbarIconButton(
                        key: const ValueKey('paper-ai-web-search'),
                        tooltip: widget.webSearchEnabled ? '关闭联网搜索' : '开启联网搜索',
                        icon: Icons.search_rounded,
                        color: widget.webSearchEnabled
                            ? PaperAiUiTokens.accent(context)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        onTap: widget.enabled && widget.webSearchAvailable
                            ? () => widget.onWebSearchChanged(
                                  !widget.webSearchEnabled,
                                )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _ToolbarIconButton(
                        key: const ValueKey('paper-ai-reasoning-setting'),
                        tooltip: '模型思考强度',
                        icon: Icons.lightbulb_outline_rounded,
                        color:
                            widget.reasoningEffort == ChatReasoningEffort.none
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : PaperAiUiTokens.accent(context),
                        onTap: widget.enabled
                            ? () => showPaperAiReasoningSheet(
                                  context,
                                  initialEffort: widget.reasoningEffort,
                                  onChanged: widget.onReasoningEffortChanged,
                                )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _ToolbarIconButton(
                        key: const ValueKey('paper-ai-clear-context'),
                        tooltip: '清除上下文',
                        icon: Icons.add_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        onTap: widget.enabled && widget.hasContext
                            ? widget.onClearContext
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                key: const ValueKey('paper-ai-composer-surface'),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
                decoration: BoxDecoration(
                  color: PaperAiUiTokens.composer(context),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(SparkDesignTokens.radius3Xl),
                    topRight: const Radius.circular(
                      SparkDesignTokens.radius3Xl,
                    ),
                    bottomLeft: Radius.circular(
                      keyboardVisible ? 0 : SparkDesignTokens.radius3Xl,
                    ),
                    bottomRight: Radius.circular(
                      keyboardVisible ? 0 : SparkDesignTokens.radius3Xl,
                    ),
                  ),
                  border: Border.all(
                    color: PaperAiUiTokens.composerBorder(context),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PaperAiUiTokens.shadow(context),
                      blurRadius: 12,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 40,
                          maxHeight: 132,
                        ),
                        child: TextField(
                          key: const ValueKey('paper-ai-input'),
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          readOnly: !widget.enabled,
                          onChanged: widget.onChanged,
                          minLines: 1,
                          maxLines: 6,
                          textAlignVertical: TextAlignVertical.top,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: SparkFontSizes.titleSmall,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: '输入消息与AI聊天',
                            hintStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: SparkFontSizes.titleSmall,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.fromLTRB(
                              2,
                              4,
                              2,
                              4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: ValueKey(
                        widget.sending
                            ? 'paper-ai-composer-stop'
                            : 'paper-ai-send',
                      ),
                      tooltip: widget.sending ? '停止生成' : '发送',
                      onPressed: widget.sending
                          ? widget.onCancel
                          : canSend
                              ? widget.onSend
                              : null,
                      style: IconButton.styleFrom(
                        backgroundColor: widget.sending || canSend
                            ? PaperAiUiTokens.accent(context)
                            : PaperAiUiTokens.disabledControl(context),
                        foregroundColor: widget.sending || canSend
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.outline,
                        minimumSize: const Size(40, 40),
                        maximumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      icon: Icon(
                        widget.sending
                            ? Icons.stop_rounded
                            : Icons.arrow_upward_rounded,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarAvatarButton extends StatelessWidget {
  const _ToolbarAvatarButton({
    super.key,
    required this.tooltip,
    required this.onTap,
  });

  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          maximumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: const PaperAiModelAvatar(size: 24),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        onTap == null ? Theme.of(context).colorScheme.outline : color;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          maximumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 24, color: resolvedColor),
      ),
    );
  }
}
