import 'package:flutter/material.dart';

import '../../domain/chat_ai_service.dart';
import 'paper_ai_composer_parts.dart';

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
              PaperAiComposerToolbar(
                enabled: widget.enabled,
                modelName: widget.modelName,
                webSearchAvailable: widget.webSearchAvailable,
                webSearchEnabled: widget.webSearchEnabled,
                onWebSearchChanged: widget.onWebSearchChanged,
                reasoningEffort: widget.reasoningEffort,
                onReasoningEffortChanged: widget.onReasoningEffortChanged,
                hasContext: widget.hasContext,
                onClearContext: widget.onClearContext,
              ),
              const SizedBox(height: 2),
              PaperAiComposerInputSurface(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                sending: widget.sending,
                canSend: canSend,
                keyboardVisible: keyboardVisible,
                onChanged: widget.onChanged,
                onSend: widget.onSend,
                onCancel: widget.onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
