import 'package:flutter/material.dart';

import '../../../core/theme/spark_design_tokens.dart';
import '../../../core/theme/spark_font_sizes.dart';
import '../application/chat_skills.dart';
import '../application/chat_conversation_controller.dart';
import '../domain/chat_ai_service.dart';
import '../domain/chat_context.dart';
import '../domain/chat_session_repository.dart';
import '../domain/chat_session_settings.dart';
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
  bool _selectionMode = false;
  bool _editingLatestPrompt = false;
  bool _fullTextEnabled = false;
  bool _fullTextLoading = false;
  final Set<int> _selectedMessageIndexes = <int>{};

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
      settingsRepository: widget.settingsRepository,
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
      backgroundColor: PaperAiUiTokens.canvas(context),
      appBar: _selectionMode
          ? _buildSelectionAppBar(context)
          : _buildChatAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView(
                key: const ValueKey('global-paper-ai-chat'),
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                    selectionMode: _selectionMode,
                    selectedMessageIndexes: _selectedMessageIndexes,
                    onToggleMessageSelection: _toggleMessageSelection,
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
          ),
          if (_selectionMode)
            _MessageSelectionBar(
              key: const ValueKey('paper-ai-selection-bar'),
              count: _selectedMessageIndexes.length,
              onCancel: _exitSelectionMode,
              onDelete: _confirmDeleteSelectedMessages,
            )
          else
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

    final editingLatestPrompt = _editingLatestPrompt;
    _editingLatestPrompt = false;
    // 发送即收起键盘；AI 回复期间与完成后保持收起，用户需要时再点按输入区。
    _composerFocusNode.unfocus();
    _composer.clear();
    setState(() {});
    if (editingLatestPrompt) {
      await _conversation.editLatestPromptAndRetry(text);
    } else {
      await _conversation.send(text);
    }
  }

  Future<void> _toggleFullText() async {
    if (_fullTextLoading || _fullTextEnabled) return;
    final loader = widget.onLoadFullText;
    if (loader == null) return;
    setState(() => _fullTextLoading = true);
    String? errorMessage;
    try {
      final nextContext = await loader();
      if (!mounted) return;
      if (_conversation.replaceContext(nextContext)) {
        _fullTextEnabled = true;
      } else {
        errorMessage = '全文上下文与当前会话不匹配，请重试。';
      }
    } catch (_) {
      errorMessage = '无法读取论文全文，请稍后重试。';
    } finally {
      if (mounted) setState(() => _fullTextLoading = false);
    }
    if (mounted && errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _showSessionSettings() async {
    final current = _conversation.settings;
    final saved = await showModalBottomSheet<ChatSessionSettings>(
      context: context,
      backgroundColor: PaperAiUiTokens.canvas(context),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SessionSettingsSheet(initial: current),
    );
    if (saved == null || !mounted) return;
    await _conversation.updateSettings(saved);
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
    if (_conversation.sending ||
        index < 0 ||
        index >= _conversation.messages.length) {
      return;
    }
    final selected = <int>{index};
    if (!_conversation.messages[index].fromUser) {
      for (var previous = index - 1; previous >= 0; previous--) {
        if (_conversation.messages[previous].fromUser) {
          selected.add(previous);
          break;
        }
      }
    }
    setState(() {
      _selectionMode = true;
      _selectedMessageIndexes
        ..clear()
        ..addAll(selected);
    });
  }

  void _toggleMessageSelection(int index) {
    if (!_selectionMode) return;
    setState(() {
      if (_selectedMessageIndexes.contains(index)) {
        _selectedMessageIndexes.remove(index);
      } else {
        _selectedMessageIndexes.add(index);
      }
      if (_selectedMessageIndexes.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedMessageIndexes.clear();
    });
  }

  Future<void> _confirmDeleteSelectedMessages() async {
    if (_selectedMessageIndexes.isEmpty) return;
    final count = _selectedMessageIndexes.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除选中的消息？'),
        content: Text('将删除 $count 条消息，此操作无法撤销。'),
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
    final selected = Set<int>.from(_selectedMessageIndexes);
    _conversation.deleteMessagesAt(selected);
    _exitSelectionMode();
  }

  PreferredSizeWidget _buildChatAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        key: const ValueKey('paper-ai-back'),
        tooltip: '返回',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      backgroundColor: PaperAiUiTokens.canvas(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 8,
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: SparkFontSizes.title,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.64,
                child: Text(
                  _conversationSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: SparkFontSizes.caption,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.fullTextAvailable)
          IconButton(
            key: const ValueKey('paper-ai-fulltext-toggle'),
            tooltip: _fullTextEnabled ? '已读取全文' : '读取论文全文',
            onPressed: _fullTextLoading ? null : _toggleFullText,
            icon: _fullTextLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _fullTextEnabled
                        ? Icons.menu_book_rounded
                        : Icons.menu_book_outlined,
                    size: 24,
                  ),
          ),
        IconButton(
          key: const ValueKey('paper-ai-session-settings'),
          tooltip: '会话设置',
          onPressed: _showSessionSettings,
          icon: const Icon(Icons.tune_rounded, size: 24),
        ),
        IconButton(
          key: const ValueKey('paper-ai-outline-toggle'),
          tooltip: _previewMode ? '返回聊天' : '查看对话大纲',
          onPressed: () => setState(() => _previewMode = !_previewMode),
          icon: Icon(
            _previewMode
                ? Icons.close_rounded
                : Icons.format_list_bulleted_rounded,
            size: 24,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        key: const ValueKey('paper-ai-selection-cancel'),
        tooltip: '取消选择',
        onPressed: _exitSelectionMode,
        icon: const Icon(Icons.close_rounded),
      ),
      backgroundColor: PaperAiUiTokens.canvas(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 8,
      title: Text(
        '选择消息',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: SparkFontSizes.title,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_selectedMessageIndexes.length} 条',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: SparkFontSizes.footnote,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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

class _MessageSelectionBar extends StatelessWidget {
  const _MessageSelectionBar({
    super.key,
    required this.count,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: PaperAiUiTokens.composer(context),
            borderRadius: BorderRadius.circular(SparkDesignTokens.radius3Xl),
            border: Border.all(color: PaperAiUiTokens.composerBorder(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '已选择 $count 条消息',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: SparkFontSizes.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('paper-ai-selection-cancel-button'),
                onPressed: onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                key: const ValueKey('paper-ai-selection-delete'),
                onPressed: count == 0 ? null : onDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  minimumSize: const Size(88, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('删除'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionSettingsSheet extends StatefulWidget {
  const _SessionSettingsSheet({required this.initial});

  final ChatSessionSettings initial;

  @override
  State<_SessionSettingsSheet> createState() => _SessionSettingsSheetState();
}

class _SessionSettingsSheetState extends State<_SessionSettingsSheet> {
  late final TextEditingController _promptController;
  late ChatResponseStyle _responseStyle;
  late final Set<String> _enabledSkills;

  @override
  void initState() {
    super.initState();
    _promptController =
        TextEditingController(text: widget.initial.customSystemPrompt ?? '');
    _responseStyle = widget.initial.responseStyle;
    _enabledSkills = Set<String>.from(widget.initial.enabledSkillIds);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '会话设置',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: SparkFontSizes.headline,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '设置仅作用于当前会话；留空使用默认提示词。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: SparkFontSizes.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('paper-ai-settings-prompt'),
                controller: _promptController,
                minLines: 3,
                maxLines: 6,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: '自定义系统提示词',
                  hintText: '例如：请始终用中文并给出公式推导。',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '回答风格',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: SparkFontSizes.bodyLarge,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final style in ChatResponseStyle.values)
                    ChoiceChip(
                      key: ValueKey('paper-ai-settings-style-${style.name}'),
                      label: Text(style.label),
                      selected: _responseStyle == style,
                      onSelected: (_) => setState(() => _responseStyle = style),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '技能',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: SparkFontSizes.bodyLarge,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              for (final skill in ChatSkills.all)
                SwitchListTile(
                  key: ValueKey('paper-ai-settings-skill-${skill.id}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    skill.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: SparkFontSizes.bodyLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: skill.description == null
                      ? null
                      : Text(
                          skill.description!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: SparkFontSizes.footnote,
                          ),
                        ),
                  value: _enabledSkills.contains(skill.id),
                  onChanged: (value) => setState(() {
                    if (value) {
                      _enabledSkills.add(skill.id);
                    } else {
                      _enabledSkills.remove(skill.id);
                    }
                  }),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('paper-ai-settings-save'),
                    onPressed: () => Navigator.pop(
                      context,
                      ChatSessionSettings(
                        customSystemPrompt:
                            _promptController.text.trim().isEmpty
                                ? null
                                : _promptController.text.trim(),
                        enabledSkillIds: _enabledSkills.toList(growable: false),
                        responseStyle: _responseStyle,
                      ),
                    ),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
