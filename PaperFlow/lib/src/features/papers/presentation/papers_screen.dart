import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/motion/motion_tokens.dart';
import '../../../core/theme/paperflow_theme.dart';
import '../application/paper_ai_service.dart';
import '../application/paper_ai_session_repository.dart';
import '../application/paper_comment_controller.dart';
import '../domain/paper.dart';
import '../application/paper_feed_controller.dart';
import '../application/paper_interaction_controller.dart';
import '../application/paper_link_service.dart';
import '../application/paper_reading_controller.dart';
import '../application/paper_share_service.dart';
import '../application/paper_translation_service.dart';
import 'widgets/paper_category_picker.dart';
import 'widgets/paper_empty_state.dart';
import 'widgets/paper_favorite_group_sheet.dart';
import 'widgets/paper_grid_card.dart';
import 'widgets/paper_reader_view.dart';
import 'widgets/papers_header.dart';

class PapersScreen extends StatefulWidget {
  const PapersScreen({
    super.key,
    required this.feedController,
    required this.interactionController,
    required this.commentController,
    required this.readingController,
    this.active = true,
    required this.aiService,
    this.webSearchAiService,
    required this.translationServiceFactory,
    this.translationRepository,
    this.aiSessionRepository,
    this.shareService,
    this.linkService,
    this.onSearch,
    this.onOpenPaperDetail,
  });

  final PaperFeedController feedController;
  final PaperInteractionController interactionController;
  final PaperCommentController commentController;
  final PaperReadingController readingController;
  final bool active;
  final PaperAiService aiService;
  final PaperAiService? webSearchAiService;
  final PaperTranslationServiceFactory translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final PaperAiSessionRepository? aiSessionRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final VoidCallback? onSearch;
  final ValueChanged<String>? onOpenPaperDetail;

  @override
  State<PapersScreen> createState() => _PapersScreenState();
}

class _PapersScreenState extends State<PapersScreen> {
  late final PageController _pageController;
  String? _activePaperId;
  DateTime? _activeSince;
  int _lastInteractionErrorRevision = 0;

  PaperFeedController get _feed => widget.feedController;
  PaperInteractionController get _interactions => widget.interactionController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _feed.currentPaperIndex,
    );
    _feed.addListener(_handleControllerChanged);
    _interactions.addListener(_handleControllerChanged);
    widget.commentController.addListener(_handleControllerChanged);
    widget.readingController.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncActivePaper());
  }

  @override
  void didUpdateWidget(PapersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncActivePaper();
          _showInteractionErrorIfNeeded();
        });
      } else {
        _finishActivePaper();
      }
    }
    if (oldWidget.feedController == widget.feedController &&
        oldWidget.interactionController == widget.interactionController &&
        oldWidget.commentController == widget.commentController &&
        oldWidget.readingController == widget.readingController) {
      return;
    }
    oldWidget.feedController.removeListener(_handleControllerChanged);
    oldWidget.interactionController.removeListener(_handleControllerChanged);
    oldWidget.commentController.removeListener(_handleControllerChanged);
    oldWidget.readingController.removeListener(_handleControllerChanged);
    if (oldWidget.interactionController != widget.interactionController) {
      _lastInteractionErrorRevision = 0;
    }
    _feed.addListener(_handleControllerChanged);
    _interactions.addListener(_handleControllerChanged);
    widget.commentController.addListener(_handleControllerChanged);
    widget.readingController.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _feed.removeListener(_handleControllerChanged);
    _interactions.removeListener(_handleControllerChanged);
    widget.commentController.removeListener(_handleControllerChanged);
    widget.readingController.removeListener(_handleControllerChanged);
    _finishActivePaper();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final papers = _feed.papers;
    return ColoredBox(
      color: PaperFlowColors.canvas,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: PapersHeader(
              key: const ValueKey('papers-header'),
              primaryIndex: _feed.primaryCategoryIndex,
              selectedTopic: _feed.topics[_feed.topicIndex],
              onPrimarySelected: _feed.selectPrimaryCategory,
              onTopicFilter: _showTopicPicker,
              onSearch: widget.onSearch ?? () {},
            ),
          ),
          Expanded(
            child: ClipRect(
              key: const ValueKey('paper-feed-viewport'),
              child: AnimatedSwitcher(
                duration: MotionTokens.duration(
                  context,
                  MotionTokens.pageDuration,
                ),
                switchInCurve: MotionTokens.enterCurve,
                switchOutCurve: MotionTokens.exitCurve,
                transitionBuilder: _buildModeTransition,
                child: _buildPaperContent(papers),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperContent(List<Paper> papers) {
    if (papers.isEmpty) {
      return PaperEmptyState(
        title: _feed.primaryCategoryIndex == 1 ? '还没有关注作者' : '当前领域暂无论文',
        message: _feed.primaryCategoryIndex == 1
            ? '关注作者后，他们的论文会出现在这里。'
            : '可以切换到“全部”或选择其他研究领域。',
        topInset: 0,
        actionLabel: _feed.primaryCategoryIndex == 1 ? '查看推荐' : '查看全部',
        onAction: _feed.primaryCategoryIndex == 1
            ? () => _feed.selectPrimaryCategory(0)
            : () => _feed.selectTopic(0),
      );
    }

    if (_feed.gridMode) {
      return MasonryGridView.count(
        key: const ValueKey('paper-grid'),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: papers.length,
        itemBuilder: (context, index) => PaperGridCard(
          paper: papers[index],
          index: index,
          liked: _interactions.isLiked(papers[index].id),
          saved: _interactions.isSaved(papers[index].id),
          onOpen: () => _openPaper(index),
          onLike: () => _interactions.toggleLike(papers[index].id),
          onSave: () => _interactions.toggleSave(papers[index].id),
          onSaveLongPress: () => _showFavoriteGroups(papers[index].id),
        ),
      );
    }

    return PageView.builder(
      key: const ValueKey('paper-feed'),
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: papers.length,
      onPageChanged: _handlePageChanged,
      itemBuilder: (context, index) {
        final paper = papers[index];
        return PaperReaderView(
          paper: paper,
          interactionController: _interactions,
          commentController: widget.commentController,
          readingController: widget.readingController,
          aiService: widget.aiService,
          webSearchAiService: widget.webSearchAiService,
          aiSessionRepository: widget.aiSessionRepository,
          translationServiceFactory: widget.translationServiceFactory,
          translationRepository: widget.translationRepository,
          shareService: widget.shareService,
          linkService: widget.linkService,
          onOpenRelatedPaper: widget.onOpenPaperDetail ?? _feed.openPaperById,
        );
      },
    );
  }

  Widget _buildModeTransition(
    Widget child,
    Animation<double> animation,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.985, end: 1.0).animate(animation),
        child: child,
      ),
    );
  }

  void _openPaper(int index) {
    _feed.openPaper(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  void _handlePageChanged(int index) {
    _feed.selectPaper(index);
    _syncActivePaper();
  }

  void _syncActivePaper() {
    if (!mounted ||
        !widget.active ||
        !widget.readingController.initialized ||
        _feed.papers.isEmpty) {
      return;
    }
    final index = _feed.currentPaperIndex.clamp(0, _feed.papers.length - 1);
    final paperId = _feed.papers[index].id;
    if (_activePaperId == paperId) return;
    _finishActivePaper();
    _activePaperId = paperId;
    _activeSince = DateTime.now();
    widget.readingController.recordOpened(paperId);
  }

  void _finishActivePaper() {
    final paperId = _activePaperId;
    final since = _activeSince;
    if (paperId != null && since != null) {
      widget.readingController.addDwellTime(
        paperId,
        DateTime.now().difference(since),
      );
    }
    _activePaperId = null;
    _activeSince = null;
  }

  void _showFavoriteGroups(String paperId) {
    showPaperFavoriteGroupSheet(
      context,
      paperId: paperId,
      controller: _interactions,
    );
  }

  Future<void> _showTopicPicker() async {
    final result = await showPaperTopicPicker(
      context,
      topics: {
        ..._feed.topics,
        ...availablePaperCategories,
      },
      selectedTopic: _feed.topics[_feed.topicIndex],
    );
    if (result == null || !mounted) return;
    _feed.selectTopicByName(result);
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _showInteractionErrorIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _feed.papers.isEmpty) {
        return;
      }
      final page = _pageController.page?.round();
      if (page != _feed.currentPaperIndex) {
        _pageController.jumpToPage(_feed.currentPaperIndex);
      }
      _syncActivePaper();
    });
  }

  void _showInteractionErrorIfNeeded() {
    final revision = _interactions.errorRevision;
    final message = _interactions.persistenceError;
    if (!widget.active ||
        message == null ||
        revision <= _lastInteractionErrorRevision) {
      return;
    }
    _lastInteractionErrorRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
