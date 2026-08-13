import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/chat_conversation_controller.dart';
import '../domain/chat_ai_service.dart';
import '../domain/chat_context.dart';
import '../domain/chat_session_repository.dart';
import '../domain/chat_session_settings.dart';
import 'paper_ai_message_selection_controller.dart';
import 'paper_ai_ui_tokens.dart';
import 'platform/paper_ai_ime_layout.dart';
import 'platform/paper_ai_keyboard_dismissal.dart';
import 'widgets/paper_ai_chat_app_bar.dart';
import 'widgets/paper_ai_composer.dart';
import 'widgets/paper_ai_content.dart';
import 'widgets/paper_ai_message_selection_bar.dart';
import 'widgets/paper_ai_session_settings_sheet.dart';

class PaperAiChatScreen extends StatefulWidget {
  const PaperAiChatScreen({
    super.key,
    required this.chatContext,
    required this.aiService,
    this.webSearchAiService,
    required this.sessionRepository,
    this.settingsRepository,
    this.screenTitle = 'ChatPaper',
    this.screenSubtitle,
    this.assistantLabel = '默认助手',
    this.modelName = 'deepseek-v4-flash',
    this.providerName = 'DeepSeek',
    this.welcomeTitle,
    this.welcomeDescription,
    this.clearConfirmation = '这会删除当前论文的全部 AI 对话记录。',
    this.fullTextAvailable = false,
    this.onLoadFullText,
    this.conversationController,
    this.onOpenSource,
    this.keyboardDismissal = platformPaperAiKeyboardDismissal,
  });

  final ChatContext chatContext;
  final ChatAiService aiService;
  final ChatAiService? webSearchAiService;
  final ChatSessionRepository sessionRepository;
  final ChatSessionSettingsRepository? settingsRepository;
  final String screenTitle;
  final String? screenSubtitle;
  final String assistantLabel;
  final String modelName;
  final String providerName;
  final String? welcomeTitle;
  final String? welcomeDescription;
  final bool fullTextAvailable;
  final Future<ChatContext> Function()? onLoadFullText;
  final String clearConfirmation;
  final ChatConversationController? conversationController;
  final Future<bool> Function(Uri uri)? onOpenSource;
  final PaperAiKeyboardDismissal keyboardDismissal;

  @override
  State<PaperAiChatScreen> createState() => _PaperAiChatScreenState();
}

class _PaperAiChatScreenState extends State<PaperAiChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final PaperAiImeAnchoringScrollController _scrollController =
      PaperAiImeAnchoringScrollController();
  final PaperAiMessageSelectionController _selectionController =
      PaperAiMessageSelectionController();
  late final ChatConversationController _conversation;
  late final bool _ownsConversation;
  bool _previewMode = false;
  bool _editingLatestPrompt = false;

  String get _conversationSubtitle =>
      widget.screenSubtitle ?? widget.chatContext.title;

  bool get _isDesktopPlatform => switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux =>
          true,
        _ => false,
      };

  @override
  void initState() {
    super.initState();
    _ownsConversation = widget.conversationController == null;
    _conversation = (widget.conversationController ??
        ChatConversationController(
          context: widget.chatContext,
          service: widget.aiService,
          webSearchService: widget.webSearchAiService,
          sessionRepository: widget.sessionRepository,
          settingsRepository: widget.settingsRepository,
        ))
      ..addListener(_handleConversationChanged);
    _selectionController.addListener(_handleSelectionChanged);
    _conversation.initialize();
  }

  @override
  void dispose() {
    _composer.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    _selectionController
      ..removeListener(_handleSelectionChanged)
      ..dispose();
    _conversation.removeListener(_handleConversationChanged);
    if (_ownsConversation) _conversation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectionActive = _selectionController.active;
    return Scaffold(
      key: const ValueKey('paper-ai-chat-screen'),
      resizeToAvoidBottomInset: defaultTargetPlatform != TargetPlatform.android,
      backgroundColor: PaperAiUiTokens.canvas(context),
      appBar: PaperAiChatAppBar(
        initialTitle: widget.screenTitle,
        subtitle: _conversationSubtitle,
        previewMode: _previewMode,
        onPreviewModeChanged: (value) => setState(() => _previewMode = value),
        onOpenSettings: _showSessionSettings,
        fullTextAvailable: widget.fullTextAvailable,
        onLoadFullText: widget.onLoadFullText,
        onApplyFullText: _conversation.replaceContext,
        selectionActive: selectionActive,
        selectionCount: _selectionController.selectedIndexes.length,
        onCancelSelection: _selectionController.clear,
      ),
      body: Column(
        children: [
          Expanded(child: _buildConversation()),
          PaperAiAndroidChatBottomBarFollower(
            scrollController: _scrollController,
            child: selectionActive
                ? PaperAiMessageSelectionBar(
                    key: const ValueKey('paper-ai-selection-bar'),
                    count: _selectionController.selectedIndexes.length,
                    onCancel: _selectionController.clear,
                    onDelete: _confirmDeleteSelectedMessages,
                  )
                : _buildComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
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
            onEdit: _editMessage,
            onOpenSource: widget.onOpenSource,
            selectionMode: _selectionController.active,
            selectedMessageIndexes: _selectionController.selectedIndexes,
            onToggleMessageSelection: _selectionController.toggle,
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
          const PaperAiAndroidImeScrollSpacer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return PaperAiComposer(
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
    );
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _conversation.sending) return;

    final editingLatestPrompt = _editingLatestPrompt;
    _editingLatestPrompt = false;
    // 移动端发送即收起键盘，AI 回复期间与完成后保持收起，用户需要时再点按输入区；
    // 桌面端保持输入框焦点，便于连续输入（点按发送按钮会夺走焦点，需显式要回）。
    if (_isDesktopPlatform) {
      _composerFocusNode.requestFocus();
    } else {
      _composerFocusNode.unfocus();
    }
    _composer.clear();
    setState(() {});
    if (editingLatestPrompt) {
      await _conversation.editLatestPromptAndRetry(text);
    } else {
      await _conversation.send(text);
    }
  }

  Future<void> _showSessionSettings() async {
    final saved = await showPaperAiSessionSettingsSheet(
      context,
      initial: _conversation.settings,
    );
    if (saved == null || !mounted) return;
    await _conversation.updateSettings(saved);
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
    if (confirmed == true) {
      _editingLatestPrompt = false;
      await _conversation.clear();
    }
  }

  void _editMessage(String content) {
    _editingLatestPrompt = true;
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
    if (_conversation.sending) return;
    if (!_selectionController.beginSelection(_conversation.messages, index)) {
      return;
    }
    // 多选以底部操作栏替换输入区，键盘留着只会遮挡内容。
    widget.keyboardDismissal.dismiss(_composerFocusNode);
  }

  Future<void> _confirmDeleteSelectedMessages() async {
    final selectedIndexes = _selectionController.selectedIndexes;
    if (selectedIndexes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除选中的消息？'),
        content: Text('将删除 ${selectedIndexes.length} 条消息，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _conversation.deleteMessagesAt(Set<int>.from(selectedIndexes));
    _selectionController.clear();
  }

  void _handleSelectionChanged() {
    if (mounted) setState(() {});
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
