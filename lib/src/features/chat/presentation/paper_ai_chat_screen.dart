import 'package:flutter/material.dart';

import '../../../core/theme/paperflow_theme.dart';
import '../application/chat_ai_service.dart';
import '../application/chat_conversation_controller.dart';
import '../domain/chat_context.dart';
import '../domain/chat_session_repository.dart';
import 'paper_ai_ui_tokens.dart';
import 'widgets/paper_ai_composer.dart';
import 'widgets/paper_ai_content.dart';

class PaperAiChatScreen extends StatefulWidget {
  const PaperAiChatScreen({
    super.key,
    required this.chatContext,
    required this.aiService,
    this.webSearchAiService,
    required this.sessionRepository,
    this.screenTitle = 'ChatPaper',
    this.screenSubtitle,
    this.assistantLabel = '默认助手',
    this.modelName = 'deepseek-v4-flash',
    this.providerName = 'DeepSeek',
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
  final String assistantLabel;
  final String modelName;
  final String providerName;
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
  bool _previewMode = false;

  String get _modelSubtitle =>
      '${widget.assistantLabel} / ${widget.modelName} (${widget.providerName})';

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
      key: const ValueKey('paper-ai-chat-screen'),
      backgroundColor: PaperAiUiTokens.canvas,
      drawer: _PaperAiDrawer(
        chatContext: widget.chatContext,
        onNewChat: _confirmClearContext,
        onClearContext: _confirmClearContext,
      ),
      appBar: AppBar(
        backgroundColor: PaperAiUiTokens.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: Builder(
          builder: (context) => IconButton(
            key: const ValueKey('paper-ai-menu'),
            tooltip: '打开对话列表',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded, size: 28),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.screenTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PaperFlowColors.ink,
                fontSize: 17,
                height: 1.1,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.62,
              child: Text(
                widget.screenSubtitle ?? _modelSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('paper-ai-outline-toggle'),
            tooltip: _previewMode ? '返回聊天' : '查看对话大纲',
            onPressed: () => setState(() => _previewMode = !_previewMode),
            icon: Icon(
              _previewMode
                  ? Icons.close_rounded
                  : Icons.format_list_bulleted_rounded,
              size: 28,
            ),
          ),
          IconButton(
            key: const ValueKey('paper-ai-new-chat'),
            tooltip: '新建对话',
            onPressed: _confirmClearContext,
            icon: const Icon(Icons.add_comment_outlined, size: 28),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('global-paper-ai-chat'),
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  welcomeTitle: widget.welcomeTitle,
                  welcomeDescription: widget.welcomeDescription,
                  prompts: widget.suggestedPrompts,
                  previewMode: _previewMode,
                  assistantLabel: widget.assistantLabel,
                  modelName: widget.modelName,
                  providerName: widget.providerName,
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
            modelName: widget.modelName,
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
        title: const Text('新建对话？'),
        content: Text(widget.clearConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('新建'),
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

class _PaperAiDrawer extends StatelessWidget {
  const _PaperAiDrawer({
    required this.chatContext,
    required this.onNewChat,
    required this.onClearContext,
  });

  final ChatContext chatContext;
  final VoidCallback onNewChat;
  final VoidCallback onClearContext;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: PaperAiUiTokens.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '对话',
                style: TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              _DrawerAction(
                icon: Icons.add_rounded,
                label: '新建对话',
                onTap: () {
                  Navigator.of(context).pop();
                  onNewChat();
                },
              ),
              _DrawerAction(
                icon: Icons.search_rounded,
                label: '搜索对话',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('对话搜索即将接入。')),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '当前会话',
                style: TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PaperAiUiTokens.userBubble.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  chatContext.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PaperFlowColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const Spacer(),
              _DrawerAction(
                icon: Icons.delete_sweep_outlined,
                label: '清除当前对话',
                onTap: () {
                  Navigator.of(context).pop();
                  onClearContext();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  const _DrawerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, size: 22, color: PaperFlowColors.ink),
      title: Text(
        label,
        style: const TextStyle(
          color: PaperFlowColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
