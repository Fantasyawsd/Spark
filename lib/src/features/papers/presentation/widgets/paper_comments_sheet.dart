import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/spark_sheet.dart';
import '../../../../core/widgets/spark_tab_bar.dart';
import '../../application/paper_comment_controller.dart';
import '../../domain/paper.dart';
import '../paper_ai_discussion_builder.dart';
import 'paper_comments_content.dart';
import 'paper_discussion_models.dart';
import 'paper_message_composer.dart';

enum PaperSheetPage { comments, ai }

Future<void> showPaperCommentsSheet(
  BuildContext context,
  Paper paper, {
  required PaperAiDiscussionBuilder aiDiscussionBuilder,
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
      aiDiscussionBuilder: aiDiscussionBuilder,
      commentController: commentController,
      generatedKeywords: generatedKeywords,
    ),
  );
}

class _PaperCommentsSheet extends StatefulWidget {
  const _PaperCommentsSheet({
    required this.paper,
    required this.initialPage,
    required this.aiDiscussionBuilder,
    required this.commentController,
    required this.generatedKeywords,
  });

  final Paper paper;
  final PaperSheetPage initialPage;
  final PaperAiDiscussionBuilder aiDiscussionBuilder;
  final PaperCommentController commentController;
  final List<String> generatedKeywords;

  @override
  State<_PaperCommentsSheet> createState() => _PaperCommentsSheetState();
}

class _PaperCommentsSheetState extends State<_PaperCommentsSheet> {
  final TextEditingController _commentComposerController =
      TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late final PageController _pageController;

  late int _pageIndex;
  bool _fullscreen = false;
  String? _replyingToId;
  final Set<String> _expandedCommentIds = {};

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialPage.index;
    _pageController = PageController(initialPage: _pageIndex);
    widget.commentController.addListener(_handleCommentsChanged);
    widget.commentController.loadPaper(widget.paper.id);
  }

  @override
  void dispose() {
    _commentComposerController.dispose();
    _sheetController.dispose();
    _pageController.dispose();
    widget.commentController.removeListener(_handleCommentsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _KeyboardInsetFollower(
      preserveTopEdge: _fullscreen,
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
                widget.aiDiscussionBuilder(
                  context,
                  paper: widget.paper,
                  generatedKeywords: widget.generatedKeywords,
                  scrollController: _pageIndex == 1 ? scrollController : null,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.bottomCenter,
            child: _pageIndex == 1
                ? const SizedBox.shrink()
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

class _KeyboardInsetFollower extends StatelessWidget {
  const _KeyboardInsetFollower({
    required this.preserveTopEdge,
    required this.child,
  });

  final bool preserveTopEdge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Transform.translate(
      offset: Offset(
        0,
        preserveTopEdge ? 0 : -mediaQuery.viewInsets.bottom,
      ),
      child: MediaQuery(
        data: mediaQuery.removeViewInsets(removeBottom: true),
        child: RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: preserveTopEdge ? mediaQuery.viewInsets.bottom : 0,
            ),
            child: child,
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
