import 'package:flutter/material.dart';

import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';

class PaperMessageComposer extends StatelessWidget {
  const PaperMessageComposer({
    super.key,
    required this.controller,
    required this.aiMode,
    this.replyTarget,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
    this.sending = false,
    this.onCancel,
  });

  final TextEditingController controller;
  final bool aiMode;
  final String? replyTarget;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final bool sending;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          color: SparkColors.card,
          child: TextField(
            key: ValueKey(
                aiMode ? 'paper-ai-message-input' : 'paper-comment-input'),
            controller: controller,
            readOnly: !enabled,
            onChanged: onChanged,
            onSubmitted: (_) {
              if (canSend) onSend();
            },
            textInputAction: TextInputAction.send,
            minLines: 1,
            maxLines: 1,
            style: const TextStyle(fontSize: SparkFontSizes.body),
            decoration: InputDecoration(
              hintText: aiMode ? '问 AI 或按住说话' : replyTarget ?? '有价值的讨论更容易被看见',
              hintStyle: const TextStyle(
                color: SparkColors.subtle,
                fontSize: SparkFontSizes.bodySmall,
              ),
              prefixIcon: aiMode
                  ? const Icon(
                      Icons.auto_awesome_rounded,
                      color: SparkColors.ink,
                      size: 20,
                    )
                  : null,
              suffixIcon: sending
                  ? aiMode
                      ? IconButton(
                          key: const ValueKey('paper-ai-composer-stop'),
                          tooltip: '停止生成',
                          onPressed: onCancel,
                          icon: const Icon(Icons.stop_rounded),
                        )
                      : const Padding(
                          key: ValueKey('paper-comment-sending'),
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                  : canSend
                      ? IconButton(
                          key: ValueKey(
                            aiMode
                                ? 'paper-ai-message-send'
                                : 'paper-comment-send',
                          ),
                          tooltip: '发送',
                          onPressed: onSend,
                          icon: const Icon(Icons.arrow_upward_rounded),
                        )
                      : Icon(
                          aiMode
                              ? Icons.graphic_eq_rounded
                              : Icons.sentiment_satisfied_alt_rounded,
                          color: SparkColors.muted,
                          size: 22,
                        ),
              filled: true,
              fillColor: SparkColors.surfaceMuted,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
