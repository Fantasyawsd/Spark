import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/feature_flags.dart';
import '../core/platform/external_http_uri.dart';
import '../core/theme/spark_theme.dart';
import '../features/ai_settings/presentation/deepseek_settings_section.dart';
import '../features/chat/application/main_ai_chat_definition.dart';
import '../features/chat/domain/chat_ai_service.dart';
import '../features/chat/domain/chat_session_repository.dart';
import '../features/chat/presentation/ai_chat_home_screen.dart';
import '../features/chat/presentation/main_ai_chat_screen.dart';
import '../features/chat/presentation/paper_ai_chat_screen.dart';
import '../features/chat/presentation/paper_ai_discussion_view.dart';
import '../features/community/data/community_post_seed.dart';
import '../features/community/presentation/community_screen.dart';
import '../features/local_data/presentation/local_data_sheet.dart';
import '../features/papers/application/paper_chat_context.dart';
import '../features/papers/application/paper_translation_service.dart';
import '../features/papers/domain/paper_comment_repository.dart';
import '../features/papers/domain/paper.dart';
import '../features/papers/domain/paper_catalog.dart';
import '../features/papers/domain/paper_interaction_repository.dart';
import '../features/papers/domain/paper_link_service.dart';
import '../features/papers/domain/paper_preference_repository.dart';
import '../features/papers/domain/paper_reading_repository.dart';
import '../features/papers/domain/paper_share.dart';
import '../features/papers/domain/paper_translation.dart';
import '../features/papers/presentation/paper_detail_screen.dart';
import '../features/papers/presentation/papers_screen.dart';
import '../features/profile/presentation/paper_shelf_list_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/search/application/paper_search_controller.dart';
import '../features/search/domain/paper_search_history_repository.dart';
import '../features/search/presentation/paper_search_screen.dart';
import 'spark_application_session.dart';
import 'spark_bottom_nav.dart';
import 'spark_dependencies.dart';

class SparkShell extends StatefulWidget {
  const SparkShell({
    super.key,
    this.features = const FeatureFlags(),
    this.dependencies,
    this.commentRepository,
    this.interactionRepository,
    this.preferenceRepository,
    this.readingRepository,
    this.searchHistoryRepository,
    this.shareService,
    this.linkService,
    this.aiService,
    this.aiSessionRepository,
    this.translationServiceFactory,
    this.translationRepository,
    this.webSearchAiService,
  });

  final FeatureFlags features;
  final SparkDependencies? dependencies;
  final PaperCommentRepository? commentRepository;
  final PaperInteractionRepository? interactionRepository;
  final PaperPreferenceRepository? preferenceRepository;
  final PaperReadingRepository? readingRepository;
  final PaperSearchHistoryRepository? searchHistoryRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final ChatAiService? aiService;
  final ChatSessionRepository? aiSessionRepository;
  final PaperTranslationServiceFactory? translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final ChatAiService? webSearchAiService;

  @override
  State<SparkShell> createState() => _SparkShellState();
}

class _SparkShellState extends State<SparkShell> {
  int _selectedIndex = 0;
  int _coveringRouteDepth = 0;
  late final SparkApplicationSession _session;

  @override
  void initState() {
    super.initState();
    final dependencies = widget.dependencies ??
        SparkDependencies.preview(
          commentRepository: widget.commentRepository,
          interactionRepository: widget.interactionRepository,
          preferenceRepository: widget.preferenceRepository,
          readingRepository: widget.readingRepository,
          searchHistoryRepository: widget.searchHistoryRepository,
          shareService: widget.shareService,
          linkService: widget.linkService,
          aiService: widget.aiService,
          webSearchAiService: widget.webSearchAiService,
          aiSessionRepository: widget.aiSessionRepository,
          translationServiceFactory: widget.translationServiceFactory,
          translationRepository: widget.translationRepository,
        );
    _session = SparkApplicationSession(dependencies)
      ..addListener(_handleSessionStateChanged)
      ..initialize();
  }

  @override
  void dispose() {
    _session
      ..removeListener(_handleSessionStateChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: SparkColors.of(context).canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                PapersScreen(
                  active: _selectedIndex == 0 && _coveringRouteDepth == 0,
                  feedController: _session.paperController.feed,
                  interactionController: _session.paperController.interactions,
                  commentController: _session.commentController,
                  readingController: _session.readingController,
                  aiDiscussionBuilder: _buildPaperAiDiscussion,
                  keywordService: _session.paperAiService,
                  translationServiceFactory: _session.translationServiceFactory,
                  translationRepository:
                      _session.dependencies.translationRepository,
                  keywordRepository: _session.dependencies.keywordRepository,
                  shareService: _session.dependencies.shareService,
                  linkService: _session.linkService,
                  onSearch: _openPaperSearch,
                  onOpenPaperDetail: (paperId) =>
                      unawaited(_openPaperDetailById(paperId)),
                  showExperimentalConferenceChannels:
                      widget.features.experimentalConferenceChannels,
                ),
                AiChatHomeScreen(
                  chatSessionController: _session.chatSessionController,
                  onOpenPaperChat: _openAiChatById,
                  onOpenMainChat: _openMainAiChat,
                ),
                if (widget.features.experimentalCommunity)
                  const CommunityScreen(posts: demoCommunityPosts),
                ProfileScreen(
                  aiSettingsBuilder: (context) => DeepSeekSettingsSection(
                    controller: _session.credentialController,
                  ),
                  localDataListenable: _session.localDataController,
                  localDataDescriptionBuilder: () =>
                      '占用 ${formatLocalDataBytes(_session.localDataController.usage.totalBytes)}',
                  onOpenLocalData: () => showLocalDataSheet(
                    context,
                    controller: _session.localDataController,
                  ),
                  catalogStatus: PaperCatalogStatusView(
                    sourceLabel: switch (
                        _session.paperController.feed.catalogSource) {
                      PaperPageSource.paperApi => 'Spark Paper API',
                      PaperPageSource.remote => 'arXiv 远程目录',
                      PaperPageSource.cache => 'arXiv 本地缓存',
                      PaperPageSource.seed => '内置论文',
                    },
                    availability: switch (
                        _session.paperController.feed.catalogSource) {
                      PaperPageSource.paperApi =>
                        PaperCatalogAvailability.online,
                      PaperPageSource.remote => PaperCatalogAvailability.online,
                      PaperPageSource.cache => PaperCatalogAvailability.offline,
                      PaperPageSource.seed => PaperCatalogAvailability.local,
                    },
                    fetchedAt: _session.paperController.feed.catalogFetchedAt,
                  ),
                  favoriteGroups:
                      _session.paperController.interactions.favoriteGroups,
                  favoritePapersByGroup: _session.favoritePapersByGroup,
                  savedCount: _session
                      .paperController.interactions.savedPaperIds.length,
                  onCreateFavoriteGroup:
                      _session.paperController.interactions.createFavoriteGroup,
                  onRenameFavoriteGroup:
                      _session.paperController.interactions.renameFavoriteGroup,
                  onDeleteFavoriteGroup:
                      _session.paperController.interactions.deleteFavoriteGroup,
                  readingHistory: _session.papersForIds(
                    _session.readingController.historyPaperIds,
                  ),
                  readLaterPapers: _session.papersForIds(
                    _session.readingController.readLaterPaperIds,
                  ),
                  onOpenPaper: (paperId) =>
                      unawaited(_openPaperDetailById(paperId)),
                  onOpenFavoriteCollection: () =>
                      unawaited(_openFavoriteCollection()),
                  onOpenReadLaterCollection: () =>
                      unawaited(_openReadLaterCollection()),
                  onOpenReadingHistory: () => unawaited(_openReadingHistory()),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SparkBottomNav(
              selectedIndex: _selectedIndex,
              showCommunity: widget.features.experimentalCommunity,
              onSelected: _handleNavigation,
            ),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(int index) {
    if (index == 0 && _selectedIndex == 0) {
      unawaited(_session.paperController.feed.refreshCatalog());
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _handleSessionStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openFavoriteCollection() {
    return _pushCoveredRoute<void>(
      MaterialPageRoute(
        builder: (context) => PaperShelfListScreen.collection(
          title: '我的收藏',
          groups: _session.paperController.interactions.favoriteGroups,
          papersByGroup: _session.favoritePapersByGroup,
          onOpenPaper: (paperId) => unawaited(_openPaperDetailById(paperId)),
        ),
      ),
    );
  }

  Future<void> _openReadLaterCollection() {
    return _openPaperShelf(
      title: '稍后阅读',
      papers: _session.papersForIds(
        _session.readingController.readLaterPaperIds,
      ),
    );
  }

  Future<void> _openReadingHistory() {
    return _openPaperShelf(
      title: '阅读历史',
      papers: _session.papersForIds(
        _session.readingController.historyPaperIds,
      ),
    );
  }

  Future<void> _openPaperShelf({
    required String title,
    required List<Paper> papers,
  }) {
    return _pushCoveredRoute<void>(
      MaterialPageRoute(
        builder: (context) => PaperShelfListScreen.flat(
          title: title,
          papers: papers,
          onOpenPaper: (paperId) => unawaited(_openPaperDetailById(paperId)),
        ),
      ),
    );
  }

  Future<void> _openPaperSearch() async {
    final controller = PaperSearchController(
      papers: _session.paperController.feed.allPapers,
      historyRepository: _session.searchHistoryRepository,
      catalogRepository: _session.dependencies.paperCatalogRepository,
    );
    try {
      await _pushCoveredRoute<void>(
        MaterialPageRoute(
          builder: (context) => PaperSearchScreen(
            controller: controller,
            onPaperSelected: _openPaperDetailById,
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openAiChat(Paper paper) async {
    final chatContext = await _session.paperChatContextLoader.load(paper);
    if (!mounted) return;
    final conversation = _session.chatConversationCoordinator.conversation(
      context: chatContext,
      service: _session.paperAiService,
      webSearchService: _session.webSearchAiService,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PaperAiChatScreen(
          chatContext: chatContext,
          aiService: _session.paperAiService,
          webSearchAiService: _session.webSearchAiService,
          sessionRepository: _session.aiSessionRepository,
          onOpenSource: _session.linkService.open,
          settingsRepository:
              _session.dependencies.chatSessionSettingsRepository,
          conversationController: conversation,
          fullTextAvailable: widget.features.experimentalPdfAi &&
              validExternalHttpUri(paper.pdfUrl) != null,
          onLoadFullText: widget.features.experimentalPdfAi
              ? () => _session.paperChatContextLoader.load(
                    paper,
                    includeFullText: true,
                  )
              : null,
        ),
      ),
    );
  }

  Widget _buildPaperAiDiscussion(
    BuildContext context, {
    required Paper paper,
    required List<String> generatedKeywords,
    required ScrollController? scrollController,
  }) {
    final chatContext = PaperChatContext.fromPaper(
      paper,
      generatedKeywords: generatedKeywords,
    );
    return PaperAiDiscussionView(
      key: ValueKey('paper-ai-discussion-${paper.id}'),
      chatContext: chatContext,
      aiService: _session.paperAiService,
      webSearchAiService: _session.webSearchAiService,
      onOpenSource: _session.linkService.open,
      sessionRepository: _session.aiSessionRepository,
      conversationController: _session.chatConversationCoordinator.conversation(
        context: chatContext,
        service: _session.paperAiService,
        webSearchService: _session.webSearchAiService,
      ),
      scrollController: scrollController,
    );
  }

  Future<void> _openAiChatById(String contextId) async {
    final paper = _session.paperController.feed.allPapers
        .where((item) => item.id == contextId)
        .firstOrNull;
    if (paper != null) await _openAiChat(paper);
  }

  Future<void> _openMainAiChat() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => MainAiChatScreen(
          aiService: _session.mainAiService,
          webSearchAiService: _session.mainWebSearchAiService,
          sessionRepository: _session.aiSessionRepository,
          settingsRepository:
              _session.dependencies.chatSessionSettingsRepository,
          onOpenSource: _session.linkService.open,
          conversationController:
              _session.chatConversationCoordinator.conversation(
            context: MainAiChatDefinition.context,
            service: _session.mainAiService,
            webSearchService: _session.mainWebSearchAiService,
          ),
        ),
      ),
    );
    await _session.chatSessionController.refresh();
  }

  Future<void> _openPaperDetailById(String paperId) async {
    var paper = _session.paperController.feed.allPapers
        .where((item) => item.id == paperId)
        .firstOrNull;
    paper ??=
        await _session.dependencies.paperCatalogRepository?.findById(paperId);
    final selectedPaper = paper;
    if (selectedPaper == null || !mounted) return;
    await _pushCoveredRoute<void>(
      MaterialPageRoute(
        builder: (context) => PaperDetailScreen(
          paper: selectedPaper,
          interactionController: _session.paperController.interactions,
          commentController: _session.commentController,
          readingController: _session.readingController,
          aiDiscussionBuilder: _buildPaperAiDiscussion,
          keywordService: _session.paperAiService,
          translationServiceFactory: _session.translationServiceFactory,
          translationRepository: _session.dependencies.translationRepository,
          keywordRepository: _session.dependencies.keywordRepository,
          shareService: _session.dependencies.shareService,
          linkService: _session.linkService,
          onOpenRelatedPaper: (relatedPaperId) =>
              unawaited(_openPaperDetailById(relatedPaperId)),
        ),
      ),
    );
  }

  Future<T?> _pushCoveredRoute<T>(Route<T> route) async {
    _changeRouteCoverage(1);
    try {
      return await Navigator.of(context).push<T>(route);
    } finally {
      _changeRouteCoverage(-1);
    }
  }

  void _changeRouteCoverage(int delta) {
    if (!mounted) return;
    setState(() {
      _coveringRouteDepth += delta;
      if (_coveringRouteDepth < 0) _coveringRouteDepth = 0;
    });
  }
}
