import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../application/chat_ai_service.dart';

class PaperAiComposer extends StatelessWidget {
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

  static const double preferredHeight = 112;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: preferredHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: Container(
            key: const ValueKey('paper-ai-composer-surface'),
            padding: const EdgeInsets.fromLTRB(12, 7, 7, 7),
            decoration: BoxDecoration(
              color: PaperFlowColors.card,
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: PaperFlowColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A182230),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('paper-ai-input'),
                    controller: controller,
                    readOnly: !enabled,
                    onChanged: onChanged,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      color: PaperFlowColors.ink,
                      fontSize: 14,
                      height: 1.35,
                    ),
                    decoration: const InputDecoration(
                      hintText: '',
                      filled: false,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.fromLTRB(4, 5, 4, 2),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  key: const ValueKey('paper-ai-composer-toolbar'),
                  height: 38,
                  child: Row(
                    children: [
                      _ReasoningButton(
                        key: const ValueKey('paper-ai-reasoning-setting'),
                        value: reasoningEffort,
                        enabled: !sending,
                        onTap: sending
                            ? null
                            : () => onReasoningEffortChanged(
                                  reasoningEffort == ChatReasoningEffort.none
                                      ? ChatReasoningEffort.high
                                      : ChatReasoningEffort.none,
                                ),
                      ),
                      const SizedBox(width: 4),
                      if (webSearchAvailable)
                        _ToolbarTextButton(
                          key: const ValueKey('paper-ai-web-search'),
                          tooltip: '联网搜索',
                          icon: Icons.travel_explore_rounded,
                          label: '联网搜索',
                          selected: webSearchEnabled,
                          onTap: sending
                              ? null
                              : () => onWebSearchChanged(!webSearchEnabled),
                        ),
                      const SizedBox(width: 2),
                      _ToolbarIconButton(
                        key: const ValueKey('paper-ai-clear-context'),
                        tooltip: '清除上下文',
                        icon: Icons.history_toggle_off_rounded,
                        onTap: sending || !hasContext ? null : onClearContext,
                      ),
                      const Spacer(),
                      IconButton.filled(
                        key: ValueKey(
                          sending ? 'paper-ai-composer-stop' : 'paper-ai-send',
                        ),
                        tooltip: sending ? '停止生成' : '发送',
                        onPressed: sending
                            ? onCancel
                            : canSend
                                ? onSend
                                : null,
                        style: IconButton.styleFrom(
                          backgroundColor: PaperFlowColors.primary,
                          disabledBackgroundColor: const Color(0xFFF0F1F4),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: PaperFlowColors.subtle,
                          minimumSize: const Size(38, 38),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          sending
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasoningButton extends StatelessWidget {
  const _ReasoningButton({
    super.key,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final ChatReasoningEffort value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value != ChatReasoningEffort.none;
    final color = !enabled
        ? PaperFlowColors.subtle
        : selected
            ? PaperFlowColors.primary
            : PaperFlowColors.muted;
    return Tooltip(
      message: selected ? '深度思考已开启' : '开启深度思考',
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: selected
              ? PaperFlowColors.primary.withValues(alpha: 0.09)
              : Colors.transparent,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(
              color: selected
                  ? PaperFlowColors.primary.withValues(alpha: 0.20)
                  : PaperFlowColors.line,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              '深度思考',
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
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
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        onTap == null ? PaperFlowColors.subtle : PaperFlowColors.muted;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          maximumSize: const Size(32, 32),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: color,
        ),
        icon: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _ToolbarTextButton extends StatelessWidget {
  const _ToolbarTextButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? PaperFlowColors.subtle
        : selected
            ? PaperFlowColors.primary
            : PaperFlowColors.muted;
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
