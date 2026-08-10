import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/config/feature_flags.dart';
import '../core/motion/motion_tokens.dart';
import '../core/navigation/spark_route_observer.dart';
import '../core/theme/spark_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/theme/theme_preference_repository.dart';
import '../features/ai_settings/application/deepseek_credential_controller.dart';
import '../features/ai_settings/presentation/deepseek_settings_section.dart';
import '../features/chat/application/chat_session_controller.dart';
import '../features/chat/application/main_ai_chat_definition.dart';
import '../features/chat/domain/chat_ai_service.dart';
import '../features/chat/domain/chat_session_repository.dart';
import '../features/chat/presentation/ai_chat_home_screen.dart';
import '../features/chat/presentation/main_ai_chat_screen.dart';
import '../features/chat/presentation/paper_ai_chat_screen.dart';
import '../features/chat/presentation/paper_ai_discussion_view.dart';
import '../features/community/data/community_post_seed.dart';
import '../features/community/presentation/community_screen.dart';
import '../features/local_data/application/local_data_controller.dart';
import '../features/local_data/domain/local_data_repository.dart';
import '../features/local_data/presentation/local_data_sheet.dart';
import '../features/papers/application/paper_chat_context.dart';
import '../features/papers/application/paper_chat_context_loader.dart';
import '../features/papers/application/paper_comment_controller.dart';
import '../features/papers/application/paper_controller.dart';
import '../features/papers/application/paper_reading_controller.dart';
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
import 'spark_bottom_nav.dart';
import 'spark_dependencies.dart';

class SparkApp extends StatefulWidget {
  const SparkApp({
    super.key,
    this.config = const AppConfig.production(),
    this.showSplash = true,
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

  final AppConfig config;
  final bool showSplash;
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
  State<SparkApp> createState() => _SparkAppState();
}

class _SparkAppState extends State<SparkApp> {
  late final SparkDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ??
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
    unawaited(
      ThemeController.instance.configure(
        _dependencies.themePreferenceRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: widget.config.applicationTitle,
        debugShowCheckedModeBanner: widget.config.showDebugBanner,
        theme: SparkTheme.light(),
        darkTheme: SparkTheme.dark(),
        themeMode: switch (ThemeController.instance.mode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        navigatorObservers: [SparkRouteObserver.instance],
        home: _SparkBootstrap(
          showSplash: widget.showSplash,
          dependencies: _dependencies,
          features: widget.config.features,
        ),
      ),
    );
  }
}

class _SparkBootstrap extends StatefulWidget {
  const _SparkBootstrap({
    required this.showSplash,
    required this.dependencies,
    required this.features,
  });

  final bool showSplash;
  final SparkDependencies dependencies;
  final FeatureFlags features;

  @override
  State<_SparkBootstrap> createState() => _SparkBootstrapState();
}

class _SparkBootstrapState extends State<_SparkBootstrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late bool _splashComplete;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _splashComplete = !widget.showSplash;
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.splashDuration,
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 42),
      TweenSequenceItem<double>(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 58,
      ),
    ]).animate(_controller);
    _scale = Tween(
      begin: 1.0,
      end: 1.035,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.showSplash) {
      _controller.addStatusListener(_handleAnimationStatus);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.showSplash || _animationStarted || _splashComplete) return;

    _animationStarted = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _controller.value = 1;
      _splashComplete = true;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = SparkShell(
      dependencies: widget.dependencies,
      features: widget.features,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        shell,
        if (!_splashComplete)
          AbsorbPointer(
            child: FadeTransition(
              opacity: _opacity,
              child: ColoredBox(
                key: const ValueKey('spark-splash'),
                color: Colors.white,
                child: Center(
                  child: ScaleTransition(
                    scale: _scale,
                    child: Image.asset(
                      'assets/images/spark_logo.png',
                      width: 240,
                      height: 240,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _splashComplete = true);
    }
  }
}

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
  late final SparkDependencies _dependencies;
  late final PaperController _paperController;
  late final PaperCommentController _commentController;
  late final PaperReadingController _readingController;
  late final ChatAiService _paperAiService;
  late final ChatAiService _webSearchAiService;
  late final ChatAiService _mainAiService;
  late final ChatAiService _mainWebSearchAiService;
  late final ChatSessionRepository _aiSessionRepository;
  late final ChatSessionController _chatSessionController;
  late final PaperSearchHistoryRepository _searchHistoryRepository;
  late final PaperTranslationServiceFactory _translationServiceFactory;
  late final PaperChatContextLoader _paperChatContextLoader;
  late final PaperLinkService _linkService;
  late final DeepSeekCredentialController _credentialController;
  late final LocalDataController _localDataController;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ??
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
    _paperController = PaperController(
      _dependencies.paperRepository,
      interactionRepository: _dependencies.interactionRepository,
      preferenceRepository: _dependencies.preferenceRepository,
      catalogRepository: _dependencies.paperCatalogRepository,
    )..addListener(_handlePaperStateChanged);
    _readingController = PaperReadingController(
      repository: _dependencies.readingRepository,
    )..addListener(_handleReadingStateChanged);
    unawaited(_readingController.initialize());
    _commentController = PaperCommentController(
      repository: _dependencies.commentRepository,
    );
    _paperAiService = _dependencies.aiService;
    _webSearchAiService = _dependencies.webSearchAiService;
    _mainAiService = _dependencies.mainAiService;
    _mainWebSearchAiService = _dependencies.mainWebSearchAiService;
    _aiSessionRepository = _dependencies.aiSessionRepository;
    _chatSessionController = ChatSessionController(
      repository: _aiSessionRepository,
      settingsRepository: _dependencies.chatSessionSettingsRepository,
      mainSessionId: MainAiChatDefinition.sessionId,
      contexts: _paperChatContexts,
    );
    unawaited(_chatSessionController.refresh());
    _translationServiceFactory = _dependencies.translationServiceFactory;
    _paperChatContextLoader = _dependencies.paperChatContextLoader;
    _searchHistoryRepository = _dependencies.searchHistoryRepository;
    _linkService = _dependencies.linkService;
    _credentialController = DeepSeekCredentialController(
      repository: _dependencies.deepSeekCredentialRepository,
      validator: _dependencies.deepSeekCredentialValidator,
    );
    unawaited(_credentialController.initialize());
    _localDataController = LocalDataController(
      repository: _dependencies.localDataRepository,
      beforeClear: _prepareLocalDataMutation,
      afterClear: _reloadAfterLocalDataMutation,
    );
    unawaited(_localDataController.initialize());
    unawaited(_initializePaperState());
  }

  @override
  void dispose() {
    _paperController
      ..removeListener(_handlePaperStateChanged)
      ..dispose();
    _commentController.dispose();
    _readingController
      ..removeListener(_handleReadingStateChanged)
      ..dispose();
    _chatSessionController.dispose();
    _credentialController.dispose();
    _localDataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SparkColors.of(context).canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                PapersScreen(
                  active: _selectedIndex == 0 && _coveringRouteDepth == 0,
                  feedController: _paperController.feed,
                  interactionController: _paperController.interactions,
                  commentController: _commentController,
                  readingController: _readingController,
                  aiDiscussionBuilder: _buildPaperAiDiscussion,
                  keywordService: _paperAiService,
                  translationServiceFactory: _translationServiceFactory,
                  translationRepository: _dependencies.translationRepository,
                  keywordRepository: _dependencies.keywordRepository,
                  shareService: _dependencies.shareService,
                  linkService: _linkService,
                  onSearch: _openPaperSearch,
                  onOpenPaperDetail: (paperId) =>
                      unawaited(_openPaperDetailById(paperId)),
                  showExperimentalConferenceChannels:
                      widget.features.experimentalConferenceChannels,
                ),
                AiChatHomeScreen(
                  chatSessionController: _chatSessionController,
                  onOpenPaperChat: _openAiChatById,
                  onOpenMainChat: _openMainAiChat,
                ),
                if (widget.features.experimentalCommunity)
                  const CommunityScreen(posts: demoCommunityPosts),
                ProfileScreen(
                  aiSettingsBuilder: (context) => DeepSeekSettingsSection(
                    controller: _credentialController,
                  ),
                  localDataListenable: _localDataController,
                  localDataDescriptionBuilder: () =>
                      '占用 ${formatLocalDataBytes(_localDataController.usage.totalBytes)}',
                  onOpenLocalData: () => showLocalDataSheet(
                    context,
                    controller: _localDataController,
                  ),
                  catalogStatus: PaperCatalogStatusView(
                    sourceLabel: switch (_paperController.feed.catalogSource) {
                      PaperPageSource.remote => 'arXiv 远程目录',
                      PaperPageSource.cache => 'arXiv 本地缓存',
                      PaperPageSource.seed => '内置论文',
                    },
                    availability: switch (_paperController.feed.catalogSource) {
                      PaperPageSource.remote => PaperCatalogAvailability.online,
                      PaperPageSource.cache => PaperCatalogAvailability.offline,
                      PaperPageSource.seed => PaperCatalogAvailability.local,
                    },
                    fetchedAt: _paperController.feed.catalogFetchedAt,
                  ),
                  favoriteGroups: _paperController.interactions.favoriteGroups,
                  favoritePapersByGroup: _favoritePapersByGroup,
                  savedCount:
                      _paperController.interactions.savedPaperIds.length,
                  onCreateFavoriteGroup:
                      _paperController.interactions.createFavoriteGroup,
                  onRenameFavoriteGroup:
                      _paperController.interactions.renameFavoriteGroup,
                  onDeleteFavoriteGroup:
                      _paperController.interactions.deleteFavoriteGroup,
                  readingHistory: _papersForIds(
                    _readingController.historyPaperIds,
                  ),
                  readLaterPapers: _papersForIds(
                    _readingController.readLaterPaperIds,
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
    setState(() => _selectedIndex = index);
  }

  void _handlePaperStateChanged() {
    _chatSessionController.updateContexts(_paperChatContexts);
    if (mounted) setState(() {});
  }

  void _handleReadingStateChanged() {
    if (mounted) setState(() {});
  }

  Iterable<ChatContextSummary> get _paperChatContexts =>
      _paperController.feed.allPapers
          .map((paper) => ChatContextSummary(id: paper.id, title: paper.title));

  Future<void> _initializePaperState() async {
    await _paperController.initialize();
    if (!mounted) return;
    await _commentController.initialize(
      _paperController.feed.allPapers.map((paper) => paper.id),
    );
    if (!mounted) return;
    _chatSessionController.updateContexts(_paperChatContexts);
  }

  Future<void> _prepareLocalDataMutation(LocalDataClearTarget target) async {
    await Future.wait([
      _paperController.interactions.flushPendingWrites(),
      _paperController.feed.flushPreferenceWrites(),
      _paperController.feed.flushCatalogOperations(),
      _commentController.flushPendingWrites(),
      _readingController.flushPendingWrites(),
      ThemeController.instance.flushPendingWrites(),
    ]);
  }

  Future<void> _reloadAfterLocalDataMutation(
    LocalDataClearTarget target,
  ) async {
    switch (target) {
      case LocalDataClearTarget.paperCache:
        return;
      case LocalDataClearTarget.chats:
        await _chatSessionController.reload();
        return;
      case LocalDataClearTarget.allBusinessData:
        await Future.wait([
          _paperController.reloadLocalState(),
          _readingController.reload(),
          _commentController.reload(
            _paperController.feed.allPapers.map((paper) => paper.id),
          ),
          _chatSessionController.reload(),
          ThemeController.instance.reload(),
        ]);
        return;
    }
  }

  List<Paper> _papersForIds(Iterable<String> ids) {
    final papersById = {
      for (final paper in _paperController.feed.allPapers) paper.id: paper,
    };
    return ids
        .map((id) => papersById[id])
        .whereType<Paper>()
        .toList(growable: false);
  }

  Map<String, List<Paper>> get _favoritePapersByGroup => {
        for (final group in _paperController.interactions.favoriteGroups)
          group.id: _papersForIds(
            _paperController.interactions.favoritePaperIds(group.id),
          ),
      };

  Future<void> _openFavoriteCollection() {
    return _pushCoveredRoute<void>(
      MaterialPageRoute(
        builder: (context) => PaperShelfListScreen.collection(
          title: '我的收藏',
          groups: _paperController.interactions.favoriteGroups,
          papersByGroup: _favoritePapersByGroup,
          onOpenPaper: (paperId) => unawaited(_openPaperDetailById(paperId)),
        ),
      ),
    );
  }

  Future<void> _openReadLaterCollection() {
    return _openPaperShelf(
      title: '稍后阅读',
      papers: _papersForIds(_readingController.readLaterPaperIds),
    );
  }

  Future<void> _openReadingHistory() {
    return _openPaperShelf(
      title: '阅读历史',
      papers: _papersForIds(_readingController.historyPaperIds),
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
      papers: _paperController.feed.allPapers,
      historyRepository: _searchHistoryRepository,
      catalogRepository: _dependencies.paperCatalogRepository,
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
    final chatContext = await _paperChatContextLoader.load(paper);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PaperAiChatScreen(
          chatContext: chatContext,
          aiService: _paperAiService,
          webSearchAiService: _webSearchAiService,
          sessionRepository: _aiSessionRepository,
          settingsRepository: _dependencies.chatSessionSettingsRepository,
          fullTextAvailable: widget.features.experimentalPdfAi &&
              validPaperUri(paper.pdfUrl) != null,
          onLoadFullText: widget.features.experimentalPdfAi
              ? () => _paperChatContextLoader.load(paper, includeFullText: true)
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
    return PaperAiDiscussionView(
      key: ValueKey('paper-ai-discussion-${paper.id}'),
      chatContext: PaperChatContext.fromPaper(
        paper,
        generatedKeywords: generatedKeywords,
      ),
      aiService: _paperAiService,
      webSearchAiService: _webSearchAiService,
      sessionRepository: _aiSessionRepository,
      scrollController: scrollController,
    );
  }

  Future<void> _openAiChatById(String contextId) async {
    final paper = _paperController.feed.allPapers
        .where((item) => item.id == contextId)
        .firstOrNull;
    if (paper != null) await _openAiChat(paper);
  }

  Future<void> _openMainAiChat() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => MainAiChatScreen(
          aiService: _mainAiService,
          webSearchAiService: _mainWebSearchAiService,
          sessionRepository: _aiSessionRepository,
          settingsRepository: _dependencies.chatSessionSettingsRepository,
        ),
      ),
    );
    await _chatSessionController.refresh();
  }

  Future<void> _openPaperDetailById(String paperId) async {
    var paper = _paperController.feed.allPapers
        .where((item) => item.id == paperId)
        .firstOrNull;
    paper ??= await _dependencies.paperCatalogRepository?.findById(paperId);
    final selectedPaper = paper;
    if (selectedPaper == null || !mounted) return;
    await _pushCoveredRoute<void>(
      MaterialPageRoute(
        builder: (context) => PaperDetailScreen(
          paper: selectedPaper,
          interactionController: _paperController.interactions,
          commentController: _commentController,
          readingController: _readingController,
          aiDiscussionBuilder: _buildPaperAiDiscussion,
          keywordService: _paperAiService,
          translationServiceFactory: _translationServiceFactory,
          translationRepository: _dependencies.translationRepository,
          keywordRepository: _dependencies.keywordRepository,
          shareService: _dependencies.shareService,
          linkService: _linkService,
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
