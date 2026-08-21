import 'package:flutter/material.dart';

import '../application/chat_conversation_controller.dart';
import '../application/main_ai_chat_definition.dart';
import '../data/side_chat_dismiss_preference_store.dart';
import '../domain/chat_ai_service.dart';
import '../domain/chat_session_repository.dart';
import '../domain/chat_session_settings.dart';
import '../domain/side_chat_fork.dart';
import 'paper_ai_chat_screen.dart';

/// 主聊天入口，支持 side chat 临时会话。
///
/// - 默认展示主聊天 [MainAiChatDefinition.context]；
/// - 点击虚线气泡进入 side chat 模式：从主聊天当前状态 fork 临时上下文与消息背景；
/// - 再次点击返回主聊天，临时会话即丢弃（内存 only，不持久化，不污染主线）。
class MainAiChatScreen extends StatefulWidget {
  const MainAiChatScreen({
    super.key,
    required this.aiService,
    this.webSearchAiService,
    required this.sessionRepository,
    this.settingsRepository,
    this.conversationController,
    this.onOpenSource,
    this.sideChatPreferenceStore,
  });

  final ChatAiService aiService;
  final ChatAiService? webSearchAiService;
  final ChatSessionRepository sessionRepository;
  final ChatSessionSettingsRepository? settingsRepository;
  final ChatConversationController? conversationController;
  final Future<bool> Function(Uri uri)? onOpenSource;
  final SideChatDismissPreferenceStore? sideChatPreferenceStore;

  @override
  State<MainAiChatScreen> createState() => _MainAiChatScreenState();
}

class _MainAiChatScreenState extends State<MainAiChatScreen> {
  bool _sideChatMode = false;
  bool _suppressDismissTip = false;
  bool _dismissTipLoaded = false;
  ChatConversationController? _sideChatController;
  late final SideChatDismissPreferenceStore _preferenceStore;

  ChatConversationController? get _mainController =>
      widget.conversationController;

  @override
  void initState() {
    super.initState();
    _preferenceStore =
        widget.sideChatPreferenceStore ?? SideChatDismissPreferenceStore();
    _loadDismissPreference();
  }

  Future<void> _loadDismissPreference() async {
    try {
      final suppressed = await _preferenceStore.load();
      if (!mounted) return;
      setState(() {
        _suppressDismissTip = suppressed;
        _dismissTipLoaded = true;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _dismissTipLoaded = true);
    }
  }

  @override
  void dispose() {
    _sideChatController?.dispose();
    super.dispose();
  }

  Future<void> _toggleSideChat() async {
    if (_sideChatMode) {
      await _exitSideChat();
    } else {
      _enterSideChat();
    }
  }

  void _enterSideChat() {
    final mainController = _mainController;
    // 无外部 controller 时，PaperAiChatScreen 内部会创建；此时无法快照背景，
    // 仍创建空背景的临时会话，保证入口可用。
    final sideContext = mainController == null
        ? SideChatFork.create(
            mainContext: MainAiChatDefinition.context,
            messages: const [],
          )
        : SideChatFork.create(
            mainContext: mainController.effectiveContext,
            messages: List.of(mainController.messages),
          );

    _sideChatController?.dispose();
    final controller = ChatConversationController(
      context: sideContext,
      service: widget.aiService,
      webSearchService: widget.webSearchAiService,
      // 不传 sessionRepository：纯内存临时会话，退出即丢弃。
    );
    // 临时会话无需从持久化恢复，直接可用。
    setState(() {
      _sideChatController = controller;
      _sideChatMode = true;
    });
  }

  Future<void> _exitSideChat() async {
    if (!_dismissTipLoaded) {
      // 偏好尚未加载完成时按默认展示提示，避免静默丢弃。
      final shouldProceed = await _showDismissTip();
      if (shouldProceed != true) return;
    } else if (!_suppressDismissTip) {
      final shouldProceed = await _showDismissTip();
      if (shouldProceed != true) return;
    }

    final controller = _sideChatController;
    _sideChatController = null;
    controller?.cancel();
    controller?.dispose();
    if (!mounted) return;
    setState(() => _sideChatMode = false);
  }

  Future<bool?> _showDismissTip() {
    var dontShowAgain = false;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('返回主聊天'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('临时聊天内容不会保存。'),
              const SizedBox(height: 12),
              InkWell(
                onTap: () =>
                    setDialogState(() => dontShowAgain = !dontShowAgain),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: dontShowAgain,
                      onChanged: (value) => setDialogState(
                        () => dontShowAgain = value ?? false,
                      ),
                    ),
                    const Text('不再显示'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('confirm-exit-side-chat'),
              onPressed: () async {
                if (dontShowAgain) {
                  try {
                    await _preferenceStore.save(true);
                    if (mounted) {
                      setState(() => _suppressDismissTip = true);
                    }
                  } on Object {
                    // 偏好保存失败不阻断返回。
                  }
                }
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // side chat 模式：用临时 controller 渲染同一套 PaperAiChatScreen，
    // 差异化通过 screenTitle/subtitle 与 canvas 体现。
    if (_sideChatMode && _sideChatController != null) {
      return PaperAiChatScreen(
        key: const ValueKey('side-chat-screen'),
        chatContext: _sideChatController!.context,
        aiService: widget.aiService,
        webSearchAiService: widget.webSearchAiService,
        sessionRepository: widget.sessionRepository,
        settingsRepository: widget.settingsRepository,
        conversationController: _sideChatController,
        onOpenSource: widget.onOpenSource,
        screenTitle: '主聊天（临时聊天）',
        screenSubtitle: '临时会话 · 退出不保存',
        welcomeTitle: '临时会话',
        welcomeDescription: '在此追问概念与背景，不会污染主线对话',
        isSideChatMode: true,
        onToggleSideChat: _toggleSideChat,
        sideChatMode: true,
      );
    }

    return PaperAiChatScreen(
      key: const ValueKey('main-chat-screen'),
      chatContext: MainAiChatDefinition.context,
      aiService: widget.aiService,
      webSearchAiService: widget.webSearchAiService,
      sessionRepository: widget.sessionRepository,
      settingsRepository: widget.settingsRepository,
      conversationController: widget.conversationController,
      onOpenSource: widget.onOpenSource,
      screenTitle: '主聊天',
      screenSubtitle: '主会话',
      welcomeTitle: '今天想研究什么？',
      welcomeDescription: '跨论文提问、整理研究思路，或联网检索最新资料',
      clearConfirmation: '这会删除主聊天中的全部 AI 对话记录。',
      isSideChatMode: false,
      onToggleSideChat: _toggleSideChat,
      sideChatMode: false,
    );
  }
}
