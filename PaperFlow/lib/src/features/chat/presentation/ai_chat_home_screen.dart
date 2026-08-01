import 'package:flutter/material.dart';

import '../../../core/theme/paperflow_theme.dart';
import '../application/chat_session_controller.dart';
import '../domain/chat_session_repository.dart';
import 'widgets/chat_session_swipe_action.dart';

class AiChatHomeScreen extends StatefulWidget {
  const AiChatHomeScreen({
    super.key,
    required this.chatSessionController,
    this.onOpenPaperChat,
    this.onOpenMainChat,
  });

  final ChatSessionController chatSessionController;
  final Future<void> Function(String contextId)? onOpenPaperChat;
  final Future<void> Function()? onOpenMainChat;

  @override
  State<AiChatHomeScreen> createState() => _AiChatHomeScreenState();
}

class _AiChatHomeScreenState extends State<AiChatHomeScreen> {
  String? _revealedSessionId;

  @override
  void initState() {
    super.initState();
    widget.chatSessionController.addListener(_handleSessionStateChanged);
    widget.chatSessionController.refresh();
  }

  @override
  void didUpdateWidget(covariant AiChatHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatSessionController == widget.chatSessionController) return;
    oldWidget.chatSessionController.removeListener(_handleSessionStateChanged);
    widget.chatSessionController.addListener(_handleSessionStateChanged);
    widget.chatSessionController.refresh();
  }

  @override
  void dispose() {
    widget.chatSessionController.removeListener(_handleSessionStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PaperFlowColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(
              height: 64,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'AI 聊天',
                    key: ValueKey('ai-chat-home-title'),
                    style: TextStyle(
                      color: PaperFlowColors.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _AiSessionList(
                loading: widget.chatSessionController.loading,
                sessions: widget.chatSessionController.entries,
                mainSession: widget.chatSessionController.mainSession,
                onOpen: _openPaperChat,
                onOpenMain: _openMainChat,
                revealedSessionId: _revealedSessionId,
                onReveal: (id) => setState(() => _revealedSessionId = id),
                onCloseActions: () => setState(() => _revealedSessionId = null),
                onTogglePinned: _togglePinnedSession,
                onDelete: _deleteSession,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPaperChat(ChatSessionEntry entry) async {
    final open = widget.onOpenPaperChat;
    if (open == null) return;
    await open(entry.context.id);
  }

  Future<void> _openMainChat() async {
    final open = widget.onOpenMainChat;
    if (open == null) return;
    await open();
  }

  Future<void> _togglePinnedSession(ChatSessionEntry entry) async {
    await widget.chatSessionController.togglePinned(entry.context.id);
    if (mounted) setState(() => _revealedSessionId = null);
  }

  Future<void> _deleteSession(ChatSessionEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话？'),
        content: const Text('该论文的本地 AI 对话记录将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-ai-session'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Color(0xFFD92D20),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.chatSessionController.delete(entry.context.id);
    if (mounted) setState(() => _revealedSessionId = null);
  }

  void _handleSessionStateChanged() {
    if (mounted) setState(() {});
  }
}

class _AiSessionList extends StatelessWidget {
  const _AiSessionList({
    required this.loading,
    required this.sessions,
    required this.mainSession,
    required this.onOpen,
    required this.onOpenMain,
    required this.revealedSessionId,
    required this.onReveal,
    required this.onCloseActions,
    required this.onTogglePinned,
    required this.onDelete,
  });

  final bool loading;
  final List<ChatSessionEntry> sessions;
  final ChatSessionSummary? mainSession;
  final ValueChanged<ChatSessionEntry> onOpen;
  final VoidCallback onOpenMain;
  final String? revealedSessionId;
  final ValueChanged<String> onReveal;
  final VoidCallback onCloseActions;
  final Future<void> Function(ChatSessionEntry session) onTogglePinned;
  final Future<void> Function(ChatSessionEntry session) onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading && sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
      itemCount: sessions.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MainAiChatCard(
            session: mainSession,
            onTap: onOpenMain,
          );
        }
        final entry = sessions[index - 1];
        final session = entry.session;
        final contextId = entry.context.id;
        return ChatSessionSwipeAction(
          sessionId: contextId,
          revealed: revealedSessionId == contextId,
          pinned: session.pinned,
          onReveal: () => onReveal(contextId),
          onClose: onCloseActions,
          onTogglePinned: () => onTogglePinned(entry),
          onDelete: () => onDelete(entry),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: ValueKey('ai-session-$contextId'),
              onTap: () => onOpen(entry),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: PaperFlowColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: PaperFlowColors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (session.pinned) ...[
                                Icon(
                                  Icons.push_pin_rounded,
                                  color: PaperFlowColors.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  entry.context.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: PaperFlowColors.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            session.preview.replaceAll('\n', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PaperFlowColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _relativeTime(session.updatedAt),
                          style: const TextStyle(
                            color: PaperFlowColors.subtle,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${session.messageCount} 条',
                          style: const TextStyle(
                            color: PaperFlowColors.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _relativeTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return '';
    final difference = DateTime.now().difference(time.toLocal());
    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
    if (difference.inDays < 1) return '${difference.inHours} 小时前';
    return '${difference.inDays} 天前';
  }
}

class _MainAiChatCard extends StatelessWidget {
  const _MainAiChatCard({required this.session, required this.onTap});

  final ChatSessionSummary? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentSession = session;
    final preview = currentSession?.preview.trim();
    return Material(
      color: const Color(0xFFFFF3F6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const ValueKey('main-ai-chat'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PaperFlowColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'PaperFlow 主聊天',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: PaperFlowColors.ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.push_pin_rounded,
                                size: 11,
                                color: PaperFlowColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '置顶',
                                style: TextStyle(
                                  color: PaperFlowColors.primary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      preview == null || preview.isEmpty
                          ? '跨论文提问、整理想法和搜索研究信息'
                          : preview.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PaperFlowColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (currentSession == null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PaperFlowColors.muted,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _AiSessionList._relativeTime(currentSession.updatedAt),
                      style: const TextStyle(
                        color: PaperFlowColors.subtle,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currentSession.messageCount} 条',
                      style: const TextStyle(
                        color: PaperFlowColors.muted,
                        fontSize: 10.5,
                      ),
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
