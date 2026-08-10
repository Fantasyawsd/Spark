import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/motion/motion_tokens.dart';
import '../../../core/theme/spark_theme.dart';
import '../../chat/chat.dart';
import '../application/paper_comment_controller.dart';
import '../domain/paper.dart';
import '../domain/paper_catalog.dart';
import '../domain/paper_keyword_repository.dart';
import '../domain/paper_time_range.dart';
import '../application/paper_feed_controller.dart';
import '../application/paper_interaction_controller.dart';
import '../application/paper_reading_controller.dart';
import '../application/paper_translation_service.dart';
import '../domain/paper_link_service.dart';
import '../domain/paper_share.dart';
import 'paper_ai_discussion_builder.dart';
import 'widgets/paper_channel_manager_sheet.dart';
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
    required this.aiDiscussionBuilder,
    required this.keywordService,
    required this.translationServiceFactory,
    this.translationRepository,
    this.keywordRepository,
    this.shareService,
    this.linkService,
    this.onSearch,
    this.onOpenPaperDetail,
    this.showExperimentalConferenceChannels = false,
  });

  final PaperFeedController feedController;
  final PaperInteractionController interactionController;
  final PaperCommentController commentController;
  final PaperReadingController readingController;
  final bool active;
  final PaperAiDiscussionBuilder aiDiscussionBuilder;
  final ChatAiService keywordService;
  final PaperTranslationServiceFactory translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final PaperKeywordRepository? keywordRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final VoidCallback? onSearch;
  final ValueChanged<String>? onOpenPaperDetail;
  final bool showExperimentalConferenceChannels;

  @override
  State<PapersScreen> createState() => _PapersScreenState();
}

class _PapersScreenState extends State<PapersScreen> {
  late final PageController _pageController;
  String? _activePaperId;
  DateTime? _activeSince;
  int _lastInteractionErrorRevision = 0;
  PaperCatalogError? _lastCatalogError;

  PaperFeedController get _feed => widget.feedController;
  PaperInteractionController get _interactions => widget.interactionController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _feed.currentPaperIndex);
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
          _showCatalogErrorIfNeeded();
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
      color: SparkColors.of(context).canvas,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: PapersHeader(
              key: const ValueKey('papers-header'),
              channels: [
                ...PapersHeader.fixedChannelLabels,
                ..._feed.userChannels.map((channel) => channel.displayName),
              ],
              selectedIndex: _feed.channelIndex,
              onChannelSelected: _feed.selectChannel,
              onManageChannels: _showChannelManager,
              onSearch: widget.onSearch ?? () {},
              timeRangeLabel: _feed.timeRange.label,
              onSelectTimeRange: _showTimeRangePicker,
              gridMode: _feed.gridMode,
              onToggleViewMode: _feed.toggleGridMode,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ClipRect(
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
                if (_feed.catalogLoading || _feed.catalogLoadingMore)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperContent(List<Paper> papers) {
    if (papers.isEmpty) {
      return PaperEmptyState(
        title: _feed.primaryCategoryIndex == 1 ? '还没有关注作者' : '当前频道暂无论文',
        message: _feed.primaryCategoryIndex == 1
            ? '关注作者后，他们的论文会出现在这里。'
            : '可以切换频道，或通过「＋」添加更多研究主题。',
        topInset: 0,
        actionLabel: _feed.primaryCategoryIndex == 1 ? '查看推荐' : '查看推荐',
        onAction: () => _feed.selectChannel(0),
      );
    }

    if (_feed.gridMode) {
      return NotificationListener<ScrollNotification>(
        onNotification: _handleGridScroll,
        child: RefreshIndicator(
          onRefresh: _feed.refreshCatalog,
          child: MasonryGridView.count(
            key: const ValueKey('paper-grid'),
            physics: const AlwaysScrollableScrollPhysics(),
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
              onOpen: () => _openPaperFromGrid(papers[index], index),
              onLike: () => _interactions.toggleLike(papers[index].id),
              onSave: () => _interactions.toggleSave(papers[index].id),
              onSaveLongPress: () => _showFavoriteGroups(papers[index].id),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _feed.refreshCatalog,
      child: PageView.builder(
        key: const ValueKey('paper-feed'),
        controller: _pageController,
        physics: const PageScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        scrollDirection: Axis.vertical,
        itemCount: papers.length,
        onPageChanged: _handlePageChanged,
        itemBuilder: (context, index) {
          final paper = papers[index];
          return PaperReaderView(
            key: ValueKey('paper-reader-${paper.id}'),
            paper: paper,
            interactionController: _interactions,
            commentController: widget.commentController,
            readingController: widget.readingController,
            aiDiscussionBuilder: widget.aiDiscussionBuilder,
            keywordService: widget.keywordService,
            translationServiceFactory: widget.translationServiceFactory,
            translationRepository: widget.translationRepository,
            keywordRepository: widget.keywordRepository,
            shareService: widget.shareService,
            linkService: widget.linkService,
            onOpenRelatedPaper: widget.onOpenPaperDetail ?? _feed.openPaperById,
            active: widget.active && index == _feed.currentPaperIndex,
          );
        },
      ),
    );
  }

  Widget _buildModeTransition(Widget child, Animation<double> animation) {
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

  void _openPaperFromGrid(Paper paper, int index) {
    final openDetail = widget.onOpenPaperDetail;
    if (openDetail != null) {
      openDetail(paper.id);
      return;
    }
    _openPaper(index);
  }

  void _handlePageChanged(int index) {
    _feed.selectPaper(index);
    _syncActivePaper();
  }

  bool _handleGridScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter <= 800) {
      unawaited(_feed.loadMoreCatalog());
    }
    return false;
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

  Future<void> _showTimeRangePicker() async {
    final selected = await showModalBottomSheet<PaperTimeRange>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('发布时间')),
            for (final range in const <PaperTimeRange>[
              PaperTimeRange.all(),
              PaperTimeRange.latestDay(),
              PaperTimeRange.last7Days(),
              PaperTimeRange.last30Days(),
            ])
              ListTile(
                leading: Icon(
                  range.storageKey == _feed.timeRange.storageKey
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(range.label),
                onTap: () => Navigator.pop(context, range),
              ),
            ListTile(
              leading: const Icon(Icons.event_rounded),
              title: const Text('选择日期'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1991),
                  lastDate: DateTime.now(),
                );
                if (date != null && context.mounted) {
                  Navigator.pop(context, PaperTimeRange.date(date));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range_rounded),
              title: const Text('自定义时间范围'),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(1991),
                  lastDate: DateTime.now(),
                  initialDateRange: _calendarRange(_feed.timeRange),
                );
                if (range != null && context.mounted) {
                  Navigator.pop(
                    context,
                    PaperTimeRange.range(range.start, range.end),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
    if (selected != null) _feed.selectTimeRange(selected);
  }

  DateTimeRange? _calendarRange(PaperTimeRange range) {
    return switch (range) {
      CustomPaperTimeRange(:final from, :final until) => DateTimeRange(
          start: from,
          end: until,
        ),
      DatePaperTimeRange(:final date) => DateTimeRange(start: date, end: date),
      _ => null,
    };
  }

  Future<void> _showChannelManager() async {
    await showPaperChannelManagerSheet(
      context,
      userChannels: _feed.userChannels,
      onChannelsChanged: (channels) => _feed.saveUserChannels(channels),
      showConferenceChannels: widget.showExperimentalConferenceChannels,
    );
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _showInteractionErrorIfNeeded();
    _showCatalogErrorIfNeeded();
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

  void _showCatalogErrorIfNeeded() {
    final error = _feed.catalogError;
    if (error == null) {
      _lastCatalogError = null;
      return;
    }
    if (!widget.active || identical(error, _lastCatalogError)) return;
    _lastCatalogError = error;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }
}
