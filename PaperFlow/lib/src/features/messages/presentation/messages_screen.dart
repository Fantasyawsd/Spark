import 'package:flutter/material.dart';

import '../../../core/theme/paperflow_theme.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../chat/application/chat_session_controller.dart';
import '../../chat/domain/chat_session_repository.dart';
import '../data/message_seed.dart';
import '../domain/message_item.dart';
import 'widgets/swipe_action_row.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.chatSessionController,
    this.onOpenAiChat,
    this.onOpenMainAiChat,
  });

  final ChatSessionController chatSessionController;
  final Future<void> Function(String contextId)? onOpenAiChat;
  final Future<void> Function()? onOpenMainAiChat;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _tabIndex = 0;
  String? _revealedAiSessionId;

  @override
  void initState() {
    super.initState();
    widget.chatSessionController.addListener(_handleSessionStateChanged);
    widget.chatSessionController.refresh();
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
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
    final direct = _tabIndex == 1;
    final visibleMessages = direct
        ? demoMessages.where((item) => item.kind == MessageKind.direct).toList()
        : demoMessages
            .where((item) => item.kind != MessageKind.direct)
            .toList();
    return ColoredBox(
      color: PaperFlowColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(
              height: 50,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '聊天',
                    style: TextStyle(
                      color: PaperFlowColors.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: _SegmentedTabs(
                labels: const ['AI 聊天', '私信', '通知'],
                selectedIndex: _tabIndex,
                onSelected: (index) => setState(() => _tabIndex = index),
              ),
            ),
            Expanded(
              child: _tabIndex == 0
                  ? _AiSessionList(
                      loading: widget.chatSessionController.loading,
                      sessions: widget.chatSessionController.entries,
                      mainSession: widget.chatSessionController.mainSession,
                      onOpen: _openAiSession,
                      onOpenMain: _openMainAiChat,
                      revealedSessionId: _revealedAiSessionId,
                      onReveal: (id) =>
                          setState(() => _revealedAiSessionId = id),
                      onCloseActions: () =>
                          setState(() => _revealedAiSessionId = null),
                      onTogglePinned: _togglePinnedSession,
                      onDelete: _deleteSession,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
                      itemCount: visibleMessages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _MessageCard(
                        item: visibleMessages[index],
                        showAvatar: direct,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAiSession(ChatSessionEntry entry) async {
    final open = widget.onOpenAiChat;
    if (open == null) return;
    await open(entry.context.id);
  }

  Future<void> _openMainAiChat() async {
    final open = widget.onOpenMainAiChat;
    if (open == null) return;
    await open();
  }

  Future<void> _togglePinnedSession(ChatSessionEntry entry) async {
    await widget.chatSessionController.togglePinned(entry.context.id);
    if (mounted) setState(() => _revealedAiSessionId = null);
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
              backgroundColor: const Color(0xFFD92D20),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.chatSessionController.delete(entry.context.id);
    if (mounted) {
      setState(() => _revealedAiSessionId = null);
    }
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
        return SwipeActionRow(
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

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs(
      {required this.labels,
      required this.selectedIndex,
      required this.onSelected});

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 47,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? PaperFlowColors.primarySoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Center(
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: selected
                          ? PaperFlowColors.primary
                          : PaperFlowColors.muted,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.item, required this.showAvatar});

  final MessageItem item;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final direct = item.kind == MessageKind.direct;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      radius: 19,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MessageIcon(item: item, showAvatar: showAvatar),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PaperFlowColors.ink,
                    fontSize: direct ? 16 : 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PaperFlowColors.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.time,
                  style: const TextStyle(
                      color: PaperFlowColors.muted, fontSize: 11)),
              const SizedBox(height: 13),
              if (item.unread > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 23),
                  height: 23,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: PaperFlowColors.primary,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                  child: Center(
                    child: Text(
                      '${item.unread}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageIcon extends StatelessWidget {
  const _MessageIcon({required this.item, required this.showAvatar});

  final MessageItem item;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    if (showAvatar && item.avatarUrl != null) {
      return ProfileAvatar(
          imageUrl: item.avatarUrl!, radius: 31, showStatus: item.unread > 0);
    }

    final data = switch (item.kind) {
      MessageKind.liked => (
          Icons.favorite_rounded,
          const Color(0xFFFFE4EA),
          PaperFlowColors.primary
        ),
      MessageKind.commented => (
          Icons.chat_bubble_rounded,
          const Color(0xFFECE9FF),
          PaperFlowColors.purple
        ),
      MessageKind.system => (
          Icons.notifications_rounded,
          const Color(0xFFE3F0FF),
          PaperFlowColors.blue
        ),
      MessageKind.direct => (
          Icons.chat_bubble_rounded,
          PaperFlowColors.primarySoft,
          PaperFlowColors.primary
        ),
    };

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(color: data.$2, shape: BoxShape.circle),
      child: Icon(data.$1, color: data.$3, size: 29),
    );
  }
}
