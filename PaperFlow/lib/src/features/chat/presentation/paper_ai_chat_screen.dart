import 'package:flutter/material.dart';

import '../../../core/theme/paperflow_theme.dart';
import '../application/chat_ai_service.dart';
import '../application/chat_conversation_controller.dart';
import '../domain/chat_context.dart';
import '../domain/chat_session_repository.dart';
import 'widgets/paper_ai_composer.dart';
import 'widgets/paper_ai_content.dart';

class PaperAiChatScreen extends StatefulWidget {
  const PaperAiChatScreen({
    super.key,
    required this.chatContext,
    required this.aiService,
    this.webSearchAiService,
    required this.sessionRepository,
    this.screenTitle = 'AI 聊天',
    this.screenSubtitle,
    this.welcomeTitle,
    this.welcomeDescription,
    this.suggestedPrompts = const [
      '解释核心方法',
      '总结实验结果',
      '分析贡献与局限',
    ],
    this.clearConfirmation = '这会删除当前论文的全部 AI 对话记录。',
  });

  final ChatContext chatContext;
  final ChatAiService aiService;
  final ChatAiService? webSearchAiService;
  final ChatSessionRepository sessionRepository;
  final String screenTitle;
  final String? screenSubtitle;
  final String? welcomeTitle;
  final String? welcomeDescription;
  final List<String> suggestedPrompts;
  final String clearConfirmation;

  @override
  State<PaperAiChatScreen> createState() => _PaperAiChatScreenState();
}

class _PaperAiChatScreenState extends State<PaperAiChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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
    _conversation.initialize();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    _conversation
      ..removeListener(_handleConversationChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.screenTitle,
              style: const TextStyle(
                color: PaperFlowColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.68,
              child: Text(
                widget.screenSubtitle ?? widget.chatContext.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('global-paper-ai-chat'),
              controller: _scrollController,
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
                  welcomeTitle: widget.welcomeTitle,
                  welcomeDescription: widget.welcomeDescription,
                  prompts: widget.suggestedPrompts,
                ),
              ],
            ),
          ),
          PaperAiComposer(
            controller: _composer,
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
            onSend: () => _send(_composer.text),
            onCancel: _conversation.cancel,
          ),
        ],
      ),
    );
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _conversation.sending) return;
    _composer.clear();
    setState(() {});
    await _conversation.send(text);
  }

  Future<void> _confirmClearContext() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除对话上下文？'),
        content: Text(widget.clearConfirmation),
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
    final shouldFollow = !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent -
                _scrollController.position.pixels <
            160;
    setState(() {});
    if (!shouldFollow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });
  }
}
