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
  final String clearConfirmation;

  @override
  State<PaperAiChatScreen> createState() => _PaperAiChatScreenState();
}

class _PaperAiChatScreenState extends State<PaperAiChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final ChatConversationController _conversation;
  late String _conversationTitle;
  bool _previewMode = false;

  String get _conversationSubtitle =>
      widget.screenSubtitle ?? widget.chatContext.title;

  @override
  void initState() {
    super.initState();
    _conversationTitle = widget.screenTitle;
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
    _composerFocusNode.dispose();
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const ValueKey('paper-ai-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        backgroundColor: PaperAiUiTokens.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Semantics(
          button: true,
          label: '编辑会话标题',
          child: GestureDetector(
            key: const ValueKey('paper-ai-title'),
            onTap: _editConversationTitle,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _conversationTitle,
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
                  width: MediaQuery.sizeOf(context).width * 0.64,
                  child: Text(
                    _conversationSubtitle,
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
          ),
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
                  onPrompt: (_) {},
                  onRetry: _conversation.retry,
                  onCancel: _conversation.cancel,
                  onDelete: _deleteMessage,
                  onFork: _forkMessage,
                  onEdit: _editMessage,
                  searching: _conversation.searching,
                  requestStatus: _conversation.requestStatus,
                  canRetryRequestError: _conversation.canRetryRequestError,
                  welcomeTitle: widget.welcomeTitle,
                  welcomeDescription: widget.welcomeDescription,
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
            focusNode: _composerFocusNode,
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

  Future<void> _editConversationTitle() async {
    var editedTitle = _conversationTitle;
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑会话标题'),
        content: TextFormField(
          key: const ValueKey('paper-ai-title-input'),
          initialValue: editedTitle,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          onChanged: (value) => editedTitle = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(hintText: '输入会话标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editedTitle),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final normalized = nextTitle?.trim();
    if (normalized != null && normalized.isNotEmpty && mounted) {
      setState(() => _conversationTitle = normalized);
    }
  }

  Future<void> _confirmClearContext() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除对话？'),
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

  void _editMessage(String content) {
    _composer.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(offset: content.length),
    );
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocusNode.requestFocus();
    });
  }

  void _deleteMessage(int index) {
    _conversation.deleteMessageAt(index);
  }

  void _forkMessage(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fork 会话将在会话分支能力接入后启用。')),
    );
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
