import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';
import 'paper_ai_message_bubbles.dart';

class ChatMessageView extends StatelessWidget {
  const ChatMessageView({
    super.key,
    required this.message,
    required this.streaming,
    required this.searching,
    this.isLatest = false,
    this.isLatestUserPrompt = false,
    this.onRetry,
    this.onDelete,
    this.onEdit,
    this.onOpenSource,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelection,
    this.assistantLabel = '默认助手',
    this.modelName = 'deepseek-v4-flash',
    this.providerName = 'DeepSeek',
  });

  final ChatMessage message;
  final bool streaming;
  final bool searching;
  final bool isLatest;
  final bool isLatestUserPrompt;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final Future<bool> Function(Uri uri)? onOpenSource;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelection;
  final String assistantLabel;
  final String modelName;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    if (!message.fromUser &&
        message.content.isEmpty &&
        message.reasoningContent.isEmpty &&
        message.sources.isEmpty) {
      return const SizedBox.shrink();
    }

    final body = message.fromUser
        ? PaperAiUserMessage(
            message: message,
            onEdit: selectionMode
                ? null
                : ((isLatest || isLatestUserPrompt) ? onEdit : null),
            selectionMode: selectionMode,
          )
        : PaperAiAssistantMessage(
            message: message,
            streaming: streaming,
            onRetry: selectionMode ? null : (isLatest ? onRetry : null),
            onDelete: selectionMode ? null : onDelete,
            onOpenSource: onOpenSource,
            selectionMode: selectionMode,
            assistantLabel: assistantLabel,
            modelName: modelName,
            providerName: providerName,
          );

    if (!selectionMode) return body;
    return PaperAiSelectableMessage(
      selected: selected,
      onTap: onToggleSelection,
      child: body,
    );
  }
}
