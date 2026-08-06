import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/spark_sheet.dart';
import '../../../../core/widgets/spark_tab_bar.dart';
import '../../application/paper_ai_conversation_controller.dart';
import '../../application/paper_ai_service.dart';
import '../../application/paper_ai_session_repository.dart';
import '../../application/paper_chat_context.dart';
import '../../application/paper_comment_controller.dart';
import '../../domain/paper.dart';
import 'paper_ai_content.dart';
import 'paper_ai_composer.dart';
import 'paper_comments_content.dart';
import 'paper_discussion_models.dart';
import 'paper_message_composer.dart';

enum PaperSheetPage { comments, ai }

Future<void> showPaperCommentsSheet(
  BuildContext context,
  Paper paper, {
  required PaperAiService aiService,
  PaperAiService? webSearchAiService,
  PaperAiSessionRepository? aiSessionRepository,
  required PaperCommentController commentController,
  PaperSheetPage initialPage = PaperSheetPage.comments,
  List<String> generatedKeywords = const [],
}) {
  return showSparkSheet<void>(
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
      commentController: commentController,
      generatedKeywords: generatedKeywords,
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
    required this.commentController,
    required this.generatedKeywords,
  });

  final Paper paper;
  final PaperSheetPage initialPage;
  final PaperAiService aiService;
  final PaperAiService? webSearchAiService;
  final PaperAiSessionRepository? aiSessionRepository;
  final PaperCommentController commentController;
  final List<String> generatedKeywords;

  @override
  State<_PaperCommentsSheet> createState() => _PaperCommentsSheetState();
}

class _PaperCommentsSheetState extends State<_PaperCommentsSheet> {
  final TextEditingController _commentComposerController =
      TextEditingController();
  final TextEditingController _aiComposerController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late final PageController _pageController;
  late final PaperAiConversationController _aiController;
  ScrollController? _contentScrollController;

  late int _pageIndex;
  bool _fullscreen = false;
  String? _replyingToId;
  final Set<String> _expandedCommentIds = {};

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialPage.index;
    _pageController = PageController(initialPage: _pageIndex);
    _aiController = PaperAiConversationController(
      paper: widget.paper,
      generatedKeywords: widget.generatedKeywords,
      service: widget.aiService,
      webSearchService: widget.webSearchAiService,
      sessionRepository: widget.aiSessionRepository,
    )..addListener(_handleAiChanged);
    widget.commentController.addListener(_handleCommentsChanged);
    _aiController.initialize();
    widget.commentController.loadPaper(widget.paper.id);
  }

  @override
  void dispose() {
    _commentComposerController.dispose();
    _aiComposerController.dispose();
    _sheetController.dispose();
    _pageController.dispose();
    widget.commentController.removeListener(_handleCommentsChanged);
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
          _buildSheetHandle(),
          _SheetHeader(
            pageIndex: _pageIndex,
            commentCount:
                '${widget.commentController.rootCommentCount(widget.paper.id)}',
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
                    _CommentSortMenu(
                      value: widget.commentController.sortFor(widget.paper.id),
                      onSelected: (sort) => widget.commentController
                          .setSort(widget.paper.id, sort),
                    ),
                    PaperCommentsContent(
                      comments: _commentsForDisplay,
                      expandedCommentIds: _expandedCommentIds,
                      onLike: _toggleCommentLike,
                      onReply: _beginReply,
                      onDelete: _deleteComment,
                      onToggleReplies: _toggleReplies,
                    ),
                    if (widget.commentController.persistenceErrorFor(
                          widget.paper.id,
                        ) !=
                        null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: Text(
                          widget.commentController.persistenceErrorFor(
                            widget.paper.id,
                          )!,
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
                      chatContext: PaperChatContext.fromPaper(
                        widget.paper,
                        generatedKeywords: widget.generatedKeywords,
                      ),
                      messages: _aiController.messages,
                      loading: _aiController.loading,
                      sending: _aiController.sending,
                      error: _aiController.error,
                      onPrompt: _sendAiText,
                      onRetry: _aiController.retry,
                      onCancel: _aiController.cancel,
                      searching: _aiController.searching,
                      requestStatus: _aiController.requestStatus,
                      canRetryRequestError: _aiController.canRetryRequestError,
                    ),
                  ],
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.bottomCenter,
            child: _pageIndex == 1
                ? PaperAiComposer(
                    controller: _aiComposerController,
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
                    onSend: () => _sendAiText(_aiComposerController.text),
                    onCancel: _aiController.cancel,
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: PaperMessageComposer(
                      controller: _commentComposerController,
                      aiMode: false,
                      replyTarget: _replyingToId == null ? null : '回复评论',
                      enabled: !widget.commentController.isSending(
                        widget.paper.id,
                      ),
                      sending: widget.commentController.isSending(
                        widget.paper.id,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSend: () =>
                          _sendComment(_commentComposerController.text),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<PaperCommentData> get _commentsForDisplay {
    final comments = widget.commentController.commentsFor(widget.paper.id);
    return comments.map((comment) {
      final replies = comment.parentId == null
          ? comments.where((item) => item.parentId == comment.id).length
          : 0;
      return PaperCommentData(
        id: comment.id,
        name: comment.name,
        initials: comment.initials,
        time: comment.time,
        location: comment.location,
        body: comment.body,
        likes: comment.likes,
        replies: replies,
        color: SparkColors.primary,
        parentId: comment.parentId,
        canDelete: comment.isLocalUser,
        liked: comment.likedByLocalUser,
      );
    }).toList(growable: false);
  }

  Widget _buildSheetHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _handleSheetDragUpdate,
      onVerticalDragEnd: _handleSheetDragEnd,
      child: const SparkSheetHandle(height: 18),
    );
  }

  void _handleSheetDragUpdate(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (viewportHeight <= 0) return;
    final delta = details.primaryDelta ?? details.delta.dy;
    final next = (_sheetController.size - (delta / viewportHeight))
        .clamp(0.50, 1.0)
        .toDouble();
    _sheetController.jumpTo(next);
  }

  void _handleSheetDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final target = _sheetController.size >= 0.75 ? 1.0 : 0.50;
    _sheetController.animateTo(
      target,
      duration: MotionTokens.duration(context, MotionTokens.sheetDuration),
      curve: MotionTokens.pageCurve,
    );
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

  Future<void> _sendComment(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || widget.commentController.isSending(widget.paper.id)) {
      return;
    }
    _commentComposerController.clear();
    final parentId = _replyingToId;
    setState(() {
      _replyingToId = null;
      if (parentId != null) _expandedCommentIds.add(parentId);
    });
    final sent = await widget.commentController.addComment(
      widget.paper.id,
      text,
      parentId: parentId,
    );
    if (!sent && mounted) {
      _commentComposerController.text = text;
      _commentComposerController.selection = TextSelection.collapsed(
        offset: text.length,
      );
      setState(() => _replyingToId = parentId);
    }
  }

  Future<void> _sendAiText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _aiController.sending) return;
    _aiComposerController.clear();
    await _aiController.send(text);
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

  void _toggleCommentLike(String id) {
    widget.commentController.toggleLike(widget.paper.id, id);
  }

  void _beginReply(String id) => setState(() => _replyingToId = id);

  void _toggleReplies(String id) {
    setState(() {
      if (!_expandedCommentIds.add(id)) _expandedCommentIds.remove(id);
    });
  }

  void _deleteComment(String id) {
    widget.commentController.deleteComment(widget.paper.id, id);
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

  void _handleCommentsChanged() {
    if (mounted) setState(() {});
  }
}

class _CommentSortMenu extends StatelessWidget {
  const _CommentSortMenu({required this.value, required this.onSelected});

  final PaperCommentSort value;
  final ValueChanged<PaperCommentSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<PaperCommentSort>(
        key: const ValueKey('paper-comment-sort'),
        tooltip: '评论排序',
        initialValue: value,
        onSelected: onSelected,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: PaperCommentSort.newest,
            child: Text('最新'),
          ),
          PopupMenuItem(
            value: PaperCommentSort.hottest,
            child: Text('最热'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value == PaperCommentSort.newest ? '最新' : '最热',
                style: const TextStyle(
                  color: SparkColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: SparkColors.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
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
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 170,
            child: SparkTabBar(
              tabs: ['评论 $commentCount', 'AI 解析'],
              selectedIndex: pageIndex,
              pageController: pageController,
              height: 44,
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
                    color: SparkColors.muted,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: SparkColors.ink,
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
