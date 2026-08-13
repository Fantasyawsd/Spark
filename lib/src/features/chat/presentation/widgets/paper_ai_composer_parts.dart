import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../domain/chat_ai_service.dart';
import '../paper_ai_ui_tokens.dart';
import 'paper_ai_composer_sheets.dart';
import 'paper_ai_model_avatar.dart';

class PaperAiComposerToolbar extends StatelessWidget {
  const PaperAiComposerToolbar({
    super.key,
    required this.enabled,
    required this.modelName,
    required this.webSearchAvailable,
    required this.webSearchEnabled,
    required this.onWebSearchChanged,
    required this.reasoningEffort,
    required this.onReasoningEffortChanged,
    required this.hasContext,
    required this.onClearContext,
  });

  final bool enabled;
  final String modelName;
  final bool webSearchAvailable;
  final bool webSearchEnabled;
  final ValueChanged<bool> onWebSearchChanged;
  final ChatReasoningEffort reasoningEffort;
  final ValueChanged<ChatReasoningEffort> onReasoningEffortChanged;
  final bool hasContext;
  final VoidCallback onClearContext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        key: const ValueKey('paper-ai-composer-toolbar'),
        height: 38,
        child: Row(
          children: [
            _ToolbarAvatarButton(
              key: const ValueKey('paper-ai-model-setting'),
              tooltip: '选择模型',
              onTap: enabled
                  ? () => showPaperAiModelSheet(context, modelName: modelName)
                  : null,
            ),
            const SizedBox(width: 8),
            _ToolbarIconButton(
              key: const ValueKey('paper-ai-web-search'),
              tooltip: webSearchEnabled ? '关闭联网搜索' : '开启联网搜索',
              icon: Icons.search_rounded,
              color: webSearchEnabled
                  ? PaperAiUiTokens.accent(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              onTap: enabled && webSearchAvailable
                  ? () => onWebSearchChanged(!webSearchEnabled)
                  : null,
            ),
            const SizedBox(width: 8),
            _ToolbarIconButton(
              key: const ValueKey('paper-ai-reasoning-setting'),
              tooltip: '模型思考强度',
              icon: Icons.lightbulb_outline_rounded,
              color: reasoningEffort == ChatReasoningEffort.none
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : PaperAiUiTokens.accent(context),
              onTap: enabled
                  ? () => showPaperAiReasoningSheet(
                        context,
                        initialEffort: reasoningEffort,
                        onChanged: onReasoningEffortChanged,
                      )
                  : null,
            ),
            const SizedBox(width: 8),
            _ToolbarIconButton(
              key: const ValueKey('paper-ai-clear-context'),
              tooltip: '清除上下文',
              icon: Icons.add_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              onTap: enabled && hasContext ? onClearContext : null,
            ),
          ],
        ),
      ),
    );
  }
}

class PaperAiComposerInputSurface extends StatelessWidget {
  const PaperAiComposerInputSurface({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.sending,
    required this.canSend,
    required this.keyboardVisible,
    required this.onChanged,
    required this.onSend,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool sending;
  final bool canSend;
  final bool keyboardVisible;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final active = sending || canSend;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('paper-ai-composer-surface'),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      decoration: BoxDecoration(
        color: PaperAiUiTokens.composer(context),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(SparkDesignTokens.radius3Xl),
          topRight: const Radius.circular(SparkDesignTokens.radius3Xl),
          bottomLeft: Radius.circular(
            keyboardVisible ? 0 : SparkDesignTokens.radius3Xl,
          ),
          bottomRight: Radius.circular(
            keyboardVisible ? 0 : SparkDesignTokens.radius3Xl,
          ),
        ),
        border: Border.all(color: PaperAiUiTokens.composerBorder(context)),
        boxShadow: [
          BoxShadow(
            color: PaperAiUiTokens.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 132),
              child: TextField(
                key: const ValueKey('paper-ai-input'),
                controller: controller,
                focusNode: focusNode,
                readOnly: !enabled,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 6,
                textAlignVertical: TextAlignVertical.top,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: SparkFontSizes.titleSmall,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: '输入消息与AI聊天',
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: SparkFontSizes.titleSmall,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: ValueKey(sending ? 'paper-ai-composer-stop' : 'paper-ai-send'),
            tooltip: sending ? '停止生成' : '发送',
            onPressed: sending
                ? onCancel
                : canSend
                    ? onSend
                    : null,
            style: IconButton.styleFrom(
              backgroundColor: active
                  ? PaperAiUiTokens.accent(context)
                  : PaperAiUiTokens.disabledControl(context),
              foregroundColor: active ? scheme.onPrimary : scheme.outline,
              minimumSize: const Size(40, 40),
              maximumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            icon: Icon(
              sending ? Icons.stop_rounded : Icons.arrow_upward_rounded,
              size: 20,
            ),
          ),
        ],
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
