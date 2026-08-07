import 'dart:async';

import 'package:flutter/material.dart';

import '../application/chat_conversation_controller.dart';
import '../domain/chat_ai_service.dart';
import '../domain/chat_context.dart';
import '../domain/chat_session_repository.dart';
import 'widgets/paper_ai_composer.dart';
import 'widgets/paper_ai_content.dart';

/// Owns the chat state used when another feature embeds a paper discussion.
class PaperAiDiscussionView extends StatefulWidget {
  const PaperAiDiscussionView({
    super.key,
    required this.chatContext,
    required this.aiService,
    this.webSearchAiService,
    this.sessionRepository,
    this.scrollController,
  });

  final ChatContext chatContext;
  final ChatAiService aiService;
  final ChatAiService? webSearchAiService;
  final ChatSessionRepository? sessionRepository;
  final ScrollController? scrollController;

  @override
  State<PaperAiDiscussionView> createState() => _PaperAiDiscussionViewState();
}

class _PaperAiDiscussionViewState extends State<PaperAiDiscussionView> {
  final TextEditingController _composerController = TextEditingController();
  late final ChatConversationController _conversation;

  @override
  void initState() {
    super.initState();
    _conversation = ChatConversationController(
      context: widget.chatContext,
      service: widget.aiService,
      webSearchService: widget.webSearchAiService,
      sessionRepository: widget.sessionRepository,
    )..addListener(_handleConversationChanged);
    unawaited(_conversation.initialize());
  }

  @override
  void dispose() {
    _composerController.dispose();
    _conversation
      ..removeListener(_handleConversationChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('paper-ai-discussion-scroll'),
            controller: widget.scrollController,
            padding: EdgeInsets.zero,
            children: [
              PaperAiContent(
                chatContext: widget.chatContext,
                messages: _conversation.messages,
                loading: _conversation.loading,
                sending: _conversation.sending,
                error: _conversation.error,
                onPrompt: _send,
                onRetry: _conversation.retry,
                onCancel: _conversation.cancel,
                searching: _conversation.searching,
                requestStatus: _conversation.requestStatus,
                canRetryRequestError: _conversation.canRetryRequestError,
              ),
            ],
          ),
        ),
        PaperAiComposer(
          controller: _composerController,
          enabled: !_conversation.sending,
          sending: _conversation.sending,
          reasoningEffort: _conversation.reasoningEffort,
          onReasoningEffortChanged: _conversation.setReasoningEffort,
          webSearchAvailable: _conversation.webSearchAvailable,
          webSearchEnabled: _conversation.webSearchEnabled,
          onWebSearchChanged: _conversation.setWebSearchEnabled,
          hasContext: _conversation.messages.isNotEmpty,
          onClearContext: _confirmClearContext,
          onChanged: (_) => setState(() {}),
          onSend: () => _send(_composerController.text),
          onCancel: _conversation.cancel,
        ),
      ],
    );
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _conversation.sending) return;
    _composerController.clear();
    await _conversation.send(text);
  }

  Future<void> _confirmClearContext() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除对话上下文？'),
        content: const Text('当前论文的全部 AI 对话记录将被删除，之后的回答不会继续参考这些消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _conversation.clear();
  }

  void _handleConversationChanged() {
    if (!mounted) return;
    final controller = widget.scrollController;
    final shouldFollow = controller != null &&
        controller.hasClients &&
        controller.position.maxScrollExtent - controller.position.pixels < 140;
    setState(() {});
    if (!shouldFollow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    });
  }
}
