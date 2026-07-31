import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/paperflow_sheet.dart';
import '../../../../core/widgets/paperflow_tab_bar.dart';
import '../../application/paper_ai_conversation_controller.dart';
import '../../application/paper_ai_service.dart';
import '../../application/paper_ai_session_repository.dart';
import '../../domain/paper.dart';
import '../../domain/paper_comment_repository.dart';
import 'paper_ai_content.dart';
import 'paper_ai_composer.dart';
import 'paper_comments_content.dart';
import 'paper_discussion_models.dart';
import 'paper_message_composer.dart';

enum PaperSheetPage { comments, ai }

Future<void> showPaperCommentsSheet(
  BuildContext context,
  PaperRecord paper, {
  required PaperAiService aiService,
  PaperAiService? webSearchAiService,
  PaperAiSessionRepository? aiSessionRepository,
  PaperCommentRepository? commentRepository,
  PaperSheetPage initialPage = PaperSheetPage.comments,
}) {
  return showPaperFlowSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: const Color(0x660B1020),
    builder: (context) => _PaperCommentsSheet(
      paper: paper,
      initialPage: initialPage,
      aiService: aiService,
      webSearchAiService: webSearchAiService,
      aiSessionRepository: aiSessionRepository,
      commentRepository: commentRepository,
    ),
  );
}

class _PaperCommentsSheet extends StatefulWidget {
  const _PaperCommentsSheet({
    required this.paper,
    required this.initialPage,
    required this.aiService,
    required this.webSearchAiService,
    required this.aiSessionRepository,
    required this.commentRepository,
  });

  final PaperRecord paper;
  final PaperSheetPage initialPage;
  final PaperAiService aiService;
  final PaperAiService? webSearchAiService;
  final PaperAiSessionRepository? aiSessionRepository;
  final PaperCommentRepository? commentRepository;

  @override
  State<_PaperCommentsSheet> createState() => _PaperCommentsSheetState();
}

class _PaperCommentsSheetState extends State<_PaperCommentsSheet> {
  final TextEditingController _composerController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late final PageController _pageController;
  late final PaperAiConversationController _aiController;
  ScrollController? _contentScrollController;

  late int _pageIndex;
  bool _fullscreen = false;
  String? _sendError;
  String? _replyingToId;
  final Set<String> _expandedCommentIds = {};
  Future<void> _commentWriteQueue = Future.value();

  List<PaperCommentData> _comments = [];

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialPage.index;
    _pageController = PageController(initialPage: _pageIndex);
    _aiController = PaperAiConversationController(
      paper: widget.paper,
      service: widget.aiService,
      webSearchService: widget.webSearchAiService,
      sessionRepository: widget.aiSessionRepository,
    )..addListener(_handleAiChanged);
    _aiController.initialize();
    _loadComments();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _sheetController.dispose();
    _pageController.dispose();
    _aiController
      ..removeListener(_handleAiChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: _handleSheetNotification,
        child: DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.50,
          minChildSize: 0.50,
          maxChildSize: 1.0,
          snap: true,
          snapSizes: const [0.50, 1.0],
          shouldCloseOnMinExtent: false,
          expand: false,
          builder: _buildSheet,
        ),
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context,
    ScrollController scrollController,
  ) {
    _contentScrollController = scrollController;
    return Container(
      key: const ValueKey('paper-comments-sheet'),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const PaperFlowSheetHandle(),
          _SheetHeader(
            pageIndex: _pageIndex,
            commentCount:
                '${_comments.where((comment) => comment.parentId == null).length}',
            fullscreen: _fullscreen,
            pageController: _pageController,
            onPageSelected: _selectPage,
            onFullscreen: _toggleFullscreen,
            onClose: () => Navigator.pop(context),
          ),
          Expanded(
            child: PageView(
              key: const ValueKey('paper-sheet-pages'),
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _pageIndex = index),
              children: [
                ListView(
                  key: const PageStorageKey('paper-comments-page'),
                  controller: _pageIndex == 0 ? scrollController : null,
                  padding: EdgeInsets.zero,
                  children: [
                    PaperCommentsContent(
                      comments: _commentsForDisplay,
                      expandedCommentIds: _expandedCommentIds,
                      onLike: _toggleCommentLike,
                      onReply: _beginReply,
                      onDelete: _deleteComment,
                      onToggleReplies: _toggleReplies,
                    ),
                    if (_sendError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: Text(
                          _sendError!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  key: const PageStorageKey('paper-ai-page'),
                  controller: _pageIndex == 1 ? scrollController : null,
                  padding: EdgeInsets.zero,
                  children: [
                    PaperAiContent(
                      paper: widget.paper,
                      messages: _aiController.messages,
                      loading: _aiController.loading,
                      sending: _aiController.sending,
                      error: _aiController.error,
                      onPrompt: _sendText,
                      onRetry: _aiController.retry,
                      onCancel: _aiController.cancel,
                      searching: _aiController.searching,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 112 + MediaQuery.paddingOf(context).bottom,
            child: _pageIndex == 1
                ? PaperAiComposer(
                    controller: _composerController,
                    enabled: !_aiController.sending,
                    sending: _aiController.sending,
                    reasoningEffort: _aiController.reasoningEffort,
                    onReasoningEffortChanged: _aiController.setReasoningEffort,
                    webSearchAvailable: _aiController.webSearchAvailable,
                    webSearchEnabled: _aiController.webSearchEnabled,
                    onWebSearchChanged: _aiController.setWebSearchEnabled,
                    hasContext: _aiController.messages.isNotEmpty,
                    onClearContext: _confirmClearAiContext,
                    onChanged: (_) => setState(() {}),
                    onSend: () => _sendText(_composerController.text),
                    onCancel: _aiController.cancel,
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: PaperMessageComposer(
                      controller: _composerController,
                      aiMode: false,
                      replyTarget: _replyingToId == null ? null : '回复评论',
                      enabled: true,
                      onChanged: (_) => setState(() {}),
                      onSend: () => _sendText(_composerController.text),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<PaperCommentData> get _commentsForDisplay {
    return _comments.map((comment) {
      if (comment.parentId != null) return comment;
      final replies =
          _comments.where((item) => item.parentId == comment.id).length;
      return _copyComment(comment, replies: replies);
    }).toList(growable: false);
  }

  bool _handleSheetNotification(DraggableScrollableNotification notification) {
    final fullscreen = notification.extent > 0.75;
    if (fullscreen != _fullscreen) {
      setState(() => _fullscreen = fullscreen);
    }
    return false;
  }

  Future<void> _toggleFullscreen() async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      _fullscreen ? 0.50 : 1.0,
      duration: MotionTokens.duration(context, MotionTokens.sheetDuration),
      curve: MotionTokens.pageCurve,
    );
  }

  void _selectPage(int index) {
    if (index == _pageIndex || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: MotionTokens.duration(context, MotionTokens.tabDuration),
      curve: MotionTokens.pageCurve,
    );
  }

  Future<void> _sendText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || (_pageIndex == 1 && _aiController.sending)) return;
    _composerController.clear();

    if (_pageIndex == 0) {
      _addLocalComment(text);
      return;
    }
    await _aiController.send(text);
  }

  void _addLocalComment(String text) {
    final parentId = _replyingToId;
    final comment = PaperCommentData(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Alex Chen',
      initials: 'AC',
      time: '刚刚',
      location: '北京',
      body: text,
      likes: 0,
      replies: 0,
      color: PaperFlowColors.primary,
      parentId: parentId,
      canDelete: true,
    );
    setState(() {
      _comments.insert(0, comment);
      _replyingToId = null;
      if (parentId != null) _expandedCommentIds.add(parentId);
    });
    _persistComments();
  }

  Future<void> _confirmClearAiContext() async {
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
    if (confirmed == true) await _aiController.clear();
  }

  Future<void> _loadComments() async {
    final repository = widget.commentRepository;
    if (repository == null) return;
    try {
      final snapshot = await repository.load(widget.paper.id);
      if (!mounted) return;
      if (snapshot.hasStoredValue) {
        final comments = snapshot.comments
            .where((comment) => !comment.id.startsWith('seed-'))
            .toList(growable: false);
        setState(() => _comments = comments.map(_toView).toList());
        if (comments.length != snapshot.comments.length) {
          await repository.save(widget.paper.id, comments);
        }
      } else {
        await repository.save(widget.paper.id, const []);
      }
    } on PaperCommentPersistenceException catch (error) {
      if (mounted) setState(() => _sendError = error.message);
    }
  }

  void _persistComments() {
    final repository = widget.commentRepository;
    if (repository == null) return;
    final records = _comments.map(_toRecord).toList(growable: false);
    _commentWriteQueue = _commentWriteQueue.then((_) async {
      try {
        await repository.save(widget.paper.id, records);
      } on PaperCommentPersistenceException catch (error) {
        if (mounted) setState(() => _sendError = error.message);
      }
    });
  }

  void _toggleCommentLike(String id) {
    final index = _comments.indexWhere((comment) => comment.id == id);
    if (index < 0) return;
    final current = _comments[index];
    setState(() {
      _comments[index] = _copyComment(
        current,
        liked: !current.liked,
        likes: current.likes + (current.liked ? -1 : 1),
      );
    });
    _persistComments();
  }

  void _beginReply(String id) => setState(() => _replyingToId = id);

  void _toggleReplies(String id) {
    setState(() {
      if (!_expandedCommentIds.add(id)) _expandedCommentIds.remove(id);
    });
  }

  void _deleteComment(String id) {
    final canDelete = _comments.any(
      (comment) => comment.id == id && comment.canDelete,
    );
    if (!canDelete) return;
    setState(() {
      _comments.removeWhere(
        (comment) => comment.id == id || comment.parentId == id,
      );
    });
    _persistComments();
  }

  PaperCommentRecord _toRecord(PaperCommentData comment) {
    return PaperCommentRecord(
      id: comment.id,
      paperId: widget.paper.id,
      name: comment.name,
      initials: comment.initials,
      time: comment.time,
      location: comment.location,
      body: comment.body,
      likes: comment.likes,
      parentId: comment.parentId,
      isLocalUser: comment.canDelete,
      likedByLocalUser: comment.liked,
    );
  }

  PaperCommentData _toView(PaperCommentRecord comment) {
    return PaperCommentData(
      id: comment.id,
      name: comment.name,
      initials: comment.initials,
      time: comment.time,
      location: comment.location,
      body: comment.body,
      likes: comment.likes,
      replies: 0,
      color: PaperFlowColors.primary,
      parentId: comment.parentId,
      canDelete: comment.isLocalUser,
      liked: comment.likedByLocalUser,
    );
  }

  PaperCommentData _copyComment(
    PaperCommentData comment, {
    int? likes,
    bool? liked,
    int? replies,
  }) {
    return PaperCommentData(
      id: comment.id,
      name: comment.name,
      initials: comment.initials,
      time: comment.time,
      location: comment.location,
      body: comment.body,
      likes: likes ?? comment.likes,
      replies: replies ?? comment.replies,
      color: comment.color,
      parentId: comment.parentId,
      canDelete: comment.canDelete,
      liked: liked ?? comment.liked,
    );
  }

  void _handleAiChanged() {
    if (!mounted) return;
    final controller = _contentScrollController;
    final shouldFollow = _pageIndex == 1 &&
        controller != null &&
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.pageIndex,
    required this.commentCount,
    required this.fullscreen,
    required this.pageController,
    required this.onPageSelected,
    required this.onFullscreen,
    required this.onClose,
  });

  final int pageIndex;
  final String commentCount;
  final bool fullscreen;
  final PageController pageController;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onFullscreen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 170,
            child: PaperFlowTabBar(
              tabs: ['评论 $commentCount', 'AI 解析'],
              selectedIndex: pageIndex,
              pageController: pageController,
              height: 48,
              indicatorWidth: 44,
              textSize: 14.5,
              onSelected: onPageSelected,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: fullscreen ? '恢复半屏' : '全屏',
                  onPressed: onFullscreen,
                  icon: Icon(
                    fullscreen
                        ? Icons.close_fullscreen_rounded
                        : Icons.open_in_full_rounded,
                    color: PaperFlowColors.muted,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: PaperFlowColors.ink,
                    size: 23,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
