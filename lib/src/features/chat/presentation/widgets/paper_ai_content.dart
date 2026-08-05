import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/paperflow_entry_animation.dart';
import '../../application/chat_conversation_controller.dart';
import '../../domain/chat_context.dart';
import '../../domain/chat_message.dart';
import '../paper_ai_ui_tokens.dart';
import 'paper_ai_message_view.dart';

class PaperAiContent extends StatelessWidget {
  const PaperAiContent({
    super.key,
    required this.chatContext,
    required this.messages,
    required this.loading,
    required this.sending,
    required this.error,
    required this.onPrompt,
    required this.onRetry,
    required this.onCancel,
    this.onDelete,
    this.onEdit,
    this.onOpenSource,
    this.selectionMode = false,
    this.selectedMessageIndexes = const <int>{},
    this.onToggleMessageSelection,
    required this.searching,
    required this.requestStatus,
    required this.canRetryRequestError,
    this.welcomeTitle,
    this.welcomeDescription,
    this.previewMode = false,
    this.assistantLabel = '默认助手',
    this.modelName = 'deepseek-v4-flash',
    this.providerName = 'DeepSeek',
  });

  final ChatContext chatContext;
  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final ValueChanged<String> onPrompt;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final ValueChanged<int>? onDelete;
  final ValueChanged<String>? onEdit;
  final Future<bool> Function(Uri uri)? onOpenSource;
  final bool selectionMode;
  final Set<int> selectedMessageIndexes;
  final ValueChanged<int>? onToggleMessageSelection;
  final bool searching;
  final ChatRequestStatus requestStatus;
  final bool canRetryRequestError;
  final String? welcomeTitle;
  final String? welcomeDescription;
  final bool previewMode;
  final String assistantLabel;
  final String modelName;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: previewMode
          ? _PaperAiOutline(
              key: const ValueKey('paper-ai-outline'),
              messages: messages,
              modelName: modelName,
            )
          : _PaperAiConversation(
              key: const ValueKey('paper-ai-conversation'),
              chatContext: chatContext,
              messages: messages,
              loading: loading,
              sending: sending,
              error: error,
              onPrompt: onPrompt,
              onRetry: onRetry,
              onCancel: onCancel,
              onDelete: onDelete,
              onEdit: onEdit,
              onOpenSource: onOpenSource,
              selectionMode: selectionMode,
              selectedMessageIndexes: selectedMessageIndexes,
              onToggleMessageSelection: onToggleMessageSelection,
              searching: searching,
              requestStatus: requestStatus,
              canRetryRequestError: canRetryRequestError,
              welcomeTitle: welcomeTitle,
              welcomeDescription: welcomeDescription,
              assistantLabel: assistantLabel,
              modelName: modelName,
              providerName: providerName,
            ),
    );
  }
}

class _PaperAiConversation extends StatelessWidget {
  const _PaperAiConversation({
    super.key,
    required this.chatContext,
    required this.messages,
    required this.loading,
    required this.sending,
    required this.error,
    required this.onPrompt,
    required this.onRetry,
    required this.onCancel,
    required this.onDelete,
    required this.onEdit,
    this.onOpenSource,
    required this.selectionMode,
    required this.selectedMessageIndexes,
    this.onToggleMessageSelection,
    required this.searching,
    required this.requestStatus,
    required this.canRetryRequestError,
    required this.welcomeTitle,
    required this.welcomeDescription,
    required this.assistantLabel,
    required this.modelName,
    required this.providerName,
  });

  final ChatContext chatContext;
  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final ValueChanged<String> onPrompt;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final ValueChanged<int>? onDelete;
  final ValueChanged<String>? onEdit;
  final Future<bool> Function(Uri uri)? onOpenSource;
  final bool selectionMode;
  final Set<int> selectedMessageIndexes;
  final ValueChanged<int>? onToggleMessageSelection;
  final bool searching;
  final ChatRequestStatus requestStatus;
  final bool canRetryRequestError;
  final String? welcomeTitle;
  final String? welcomeDescription;
  final String assistantLabel;
  final String modelName;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final latestUserIndex = messages.lastIndexWhere(
      (message) => message.fromUser,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (messages.isEmpty && !loading)
            _AiWelcome(
              chatContext: chatContext,
              title: welcomeTitle,
              description: welcomeDescription,
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (messages.isNotEmpty) ...[
            for (var index = 0; index < messages.length; index++)
              if (!_isEmptyAssistant(messages[index]))
                PaperEntryAnimation(
                  key: ValueKey(
                    'ai-message-$index-${messages[index].fromUser}',
                  ),
                  child: PaperAiMessageView(
                    message: messages[index],
                    streaming: sending && index == messages.length - 1,
                    searching: searching && index == messages.length - 1,
                    isLatest: index == messages.length - 1,
                    isLatestUserPrompt: index == latestUserIndex,
                    onRetry: sending ? null : onRetry,
                    onDelete: () => onDelete?.call(index),
                    onEdit: sending
                        ? null
                        : () => onEdit?.call(messages[index].content),
                    onOpenSource: onOpenSource,
                    selectionMode: selectionMode,
                    selected: selectedMessageIndexes.contains(index),
                    onToggleSelection: () =>
                        onToggleMessageSelection?.call(index),
                    assistantLabel: assistantLabel,
                    modelName: modelName,
                    providerName: providerName,
                  ),
                ),
          ],
          if (sending &&
              (searching ||
                  messages.isEmpty ||
                  messages.last.fromUser ||
                  _isEmptyAssistant(messages.last)))
            _TypingIndicator(onCancel: onCancel, searching: searching),
          if (error != null)
            _AiErrorMessage(
              message: error!,
              onRetry: canRetryRequestError ? onRetry : null,
            ),
          if (error == null && requestStatus == ChatRequestStatus.cancelled)
            _AiStoppedMessage(onRetry: onRetry),
        ],
      ),
    );
  }

  static bool _isEmptyAssistant(ChatMessage message) {
    return !message.fromUser &&
        message.content.isEmpty &&
        message.reasoningContent.isEmpty &&
        message.sources.isEmpty;
  }
}

class _PaperAiOutline extends StatelessWidget {
  const _PaperAiOutline({
    super.key,
    required this.messages,
    required this.modelName,
  });

  final List<ChatMessage> messages;
  final String modelName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '对话大纲',
            style: TextStyle(
              color: PaperFlowColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            messages.isEmpty ? '还没有消息' : '$modelName · ${messages.length} 条消息',
            style: const TextStyle(
              color: PaperFlowColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          if (messages.isEmpty)
            const _OutlineEmptyState()
          else
            for (var index = 0; index < messages.length; index++)
              _OutlineRow(index: index + 1, message: messages[index]),
        ],
      ),
    );
  }
}

class _OutlineRow extends StatelessWidget {
  const _OutlineRow({required this.index, required this.message});

  final int index;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final preview = message.content.trim().isNotEmpty
        ? message.content.trim()
        : message.reasoningContent.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: message.fromUser
                  ? PaperAiUiTokens.userBubble
                  : PaperAiUiTokens.assistantReasoning,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fromUser ? '用户' : 'Assistant',
                  style: const TextStyle(
                    color: PaperFlowColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  preview.isEmpty ? '多媒体或空消息' : preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PaperFlowColors.ink,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineEmptyState extends StatelessWidget {
  const _OutlineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PaperAiUiTokens.assistantReasoning.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        '发送第一条消息后，这里会显示会话大纲。',
        style: TextStyle(
          color: PaperFlowColors.muted,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

class _AiStoppedMessage extends StatelessWidget {
  const _AiStoppedMessage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('paper-ai-cancelled'),
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: PaperAiUiTokens.assistantReasoning.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.stop_circle_outlined,
            size: 18,
            color: PaperFlowColors.muted,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '已停止生成',
              style: TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('paper-ai-regenerate'),
            onPressed: onRetry,
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
  }
}

class _AiWelcome extends StatelessWidget {
  const _AiWelcome({
    required this.chatContext,
    this.title,
    this.description,
  });

  final ChatContext chatContext;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AssistantAvatar(size: 38),
              const SizedBox(width: 10),
              Text(
                title ?? '与论文对话',
                style: const TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description ?? 'DeepSeek 已读取《${chatContext.title}》的摘要和元数据。',
            style: const TextStyle(
              color: PaperFlowColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiErrorMessage extends StatelessWidget {
  const _AiErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('paper-ai-error'),
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 19,
            color: PaperFlowColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: PaperFlowColors.danger,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              key: const ValueKey('paper-ai-retry'),
              onPressed: onRetry,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.onCancel, required this.searching});

  final VoidCallback onCancel;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _AssistantAvatar(size: 34),
          const SizedBox(width: 10),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              searching ? '正在联网检索…' : '正在组织回答…',
              style: const TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 12.5,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('paper-ai-stop'),
            tooltip: '停止生成',
            onPressed: onCancel,
            icon: const Icon(Icons.stop_circle_outlined, size: 21),
            color: PaperFlowColors.muted,
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF4B83F5), Color(0xFFB9D5FF)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        boxShadow: [
          BoxShadow(
            color: PaperAiUiTokens.modelBlue.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          'https://www.deepseek.com/favicon.ico',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }
}
