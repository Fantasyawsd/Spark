import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../application/paper_ai_service.dart';
import '../../domain/paper.dart';
import 'paper_ai_message_view.dart';
import 'paper_entry_animation.dart';

class PaperAiContent extends StatelessWidget {
  const PaperAiContent({
    super.key,
    required this.paper,
    required this.messages,
    required this.loading,
    required this.sending,
    required this.error,
    required this.onPrompt,
    required this.onRetry,
    required this.onCancel,
    required this.searching,
    this.welcomeTitle,
    this.welcomeDescription,
    this.prompts = const ['解释核心方法', '总结实验结果', '分析贡献与局限'],
  });

  final PaperRecord paper;
  final List<PaperAiMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final ValueChanged<String> onPrompt;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final bool searching;
  final String? welcomeTitle;
  final String? welcomeDescription;
  final List<String> prompts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConversationContext(paper: paper),
          const SizedBox(height: 12),
          if (messages.isEmpty && !loading)
            _AiWelcome(
              paper: paper,
              prompts: prompts,
              onPrompt: onPrompt,
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
              PaperEntryAnimation(
                key: ValueKey('ai-message-$index-${messages[index].fromUser}'),
                child: PaperAiMessageView(
                  message: messages[index],
                  streaming: sending && index == messages.length - 1,
                  searching: searching && index == messages.length - 1,
                ),
              ),
          ],
          if (sending &&
              (searching ||
                  messages.isEmpty ||
                  messages.last.fromUser ||
                  _isEmptyAssistant(messages.last)))
            _TypingIndicator(onCancel: onCancel, searching: searching),
          if (error != null) _AiErrorMessage(message: error!, onRetry: onRetry),
        ],
      ),
    );
  }

  static bool _isEmptyAssistant(PaperAiMessage message) {
    return !message.fromUser &&
        message.content.isEmpty &&
        message.reasoningContent.isEmpty &&
        message.sources.isEmpty;
  }
}

class _ConversationContext extends StatelessWidget {
  const _ConversationContext({required this.paper});

  final PaperRecord paper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.article_outlined,
              size: 14,
              color: PaperFlowColors.primary,
            ),
            const SizedBox(width: 6),
            const Text(
              '当前上下文',
              style: TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                paper.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'AI 生成内容可能有误，请结合论文原文核验。',
          style: TextStyle(
            color: PaperFlowColors.subtle,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _AiWelcome extends StatelessWidget {
  const _AiWelcome({
    required this.paper,
    required this.prompts,
    required this.onPrompt,
    this.title,
    this.description,
  });

  final PaperRecord paper;
  final List<String> prompts;
  final ValueChanged<String> onPrompt;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: PaperFlowColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: PaperFlowColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                title ?? '与论文对话',
                style: const TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            description ?? 'DeepSeek 已读取《${paper.title}》的摘要和元数据',
            style: const TextStyle(
              color: PaperFlowColors.muted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in prompts)
                ActionChip(
                  label: Text(prompt),
                  onPressed: () => onPrompt(prompt),
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  labelStyle: const TextStyle(
                    color: PaperFlowColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiErrorMessage extends StatelessWidget {
  const _AiErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('paper-ai-error'),
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(13, 10, 7, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: PaperFlowColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: PaperFlowColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              searching ? '正在联网检索…' : '正在组织回答…',
              style: const TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('paper-ai-stop'),
            tooltip: '停止生成',
            onPressed: onCancel,
            icon: const Icon(Icons.stop_circle_outlined, size: 20),
            color: PaperFlowColors.muted,
          ),
        ],
      ),
    );
  }
}
