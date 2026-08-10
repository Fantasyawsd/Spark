import 'package:flutter/material.dart';

import '../../../core/theme/spark_design_tokens.dart';
import '../../../core/theme/spark_font_sizes.dart';
import '../application/chat_session_controller.dart';
import '../domain/chat_session_repository.dart';
import 'paper_ai_ui_tokens.dart';
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
      color: PaperAiUiTokens.canvas(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ChatPaper',
                    key: ValueKey('ai-chat-home-title'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: SparkFontSizes.headline,
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
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
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
    final showEmptyHint = sessions.isEmpty;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
      itemCount: sessions.length + 1 + (showEmptyHint ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MainAiChatCard(
            session: mainSession,
            onTap: onOpenMain,
          );
        }
        if (showEmptyHint && index == 1) {
          return const _NoPaperSessionsHint();
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(SparkDesignTokens.radius2Xl),
            child: InkWell(
              key: ValueKey('ai-session-$contextId'),
              onTap: () => onOpen(entry),
              borderRadius: BorderRadius.circular(SparkDesignTokens.radius2Xl),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  entry.context.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: SparkFontSizes.body,
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
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: SparkFontSizes.footnote,
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: SparkFontSizes.caption,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${session.messageCount} 条',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: SparkFontSizes.caption,
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
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(SparkDesignTokens.radius2Xl),
      child: InkWell(
        key: const ValueKey('main-ai-chat'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkDesignTokens.radius2Xl),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
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
                        Flexible(
                          child: Text(
                            'Spark 主聊天',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontSize: SparkFontSizes.bodyLarge,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.push_pin_rounded,
                                size: 11,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '置顶',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: SparkFontSizes.tiny,
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: SparkFontSizes.footnote,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (currentSession == null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _AiSessionList._relativeTime(currentSession.updatedAt),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: SparkFontSizes.caption,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currentSession.messageCount} 条',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: SparkFontSizes.caption,
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

class _NoPaperSessionsHint extends StatelessWidget {
  const _NoPaperSessionsHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('ai-chat-empty-hint'),
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 30,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            '暂无论文解读会话，从论文页打开「AI 解读」开始',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: SparkFontSizes.footnote,
            ),
          ),
        ],
      ),
    );
  }
}
