import 'dart:async';

import 'package:flutter/material.dart';

import '../core/navigation/paperflow_route_observer.dart';
import '../core/theme/paperflow_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/paperflow_bottom_nav.dart';
import '../features/ai_settings/application/deepseek_credential_controller.dart';
import '../features/chat/application/chat_session_controller.dart';
import '../features/chat/application/main_ai_chat_definition.dart';
import '../features/chat/presentation/ai_chat_home_screen.dart';
import '../features/chat/presentation/main_ai_chat_screen.dart';
import '../features/chat/presentation/paper_ai_chat_screen.dart';
import '../features/local_data/application/local_data_controller.dart';
import '../features/local_data/domain/local_data_repository.dart';
import '../features/papers/application/paper_ai_service.dart';
import '../features/papers/application/paper_ai_session_repository.dart';
import '../features/papers/application/paper_comment_controller.dart';
import '../features/papers/application/paper_controller.dart';
import '../features/papers/application/paper_chat_context.dart';
import '../features/papers/application/paper_link_service.dart';
import '../features/papers/application/paper_reading_controller.dart';
import '../features/papers/application/paper_share_service.dart';
import '../features/papers/application/paper_translation_service.dart';
import '../features/papers/domain/paper_comment_repository.dart';
import '../features/papers/domain/paper.dart';
import '../features/papers/domain/paper_interaction_repository.dart';
import '../features/papers/domain/paper_preference_repository.dart';
import '../features/papers/domain/paper_reading_repository.dart';
import '../features/papers/presentation/paper_detail_screen.dart';
import '../features/papers/presentation/papers_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/search/application/paper_search_controller.dart';
import '../features/search/domain/paper_search_history_repository.dart';
import '../features/search/presentation/paper_search_screen.dart';
import 'paperflow_dependencies.dart';

class PaperFlowApp extends StatefulWidget {
  const PaperFlowApp({
    super.key,
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

  final bool showSplash;
  final PaperFlowDependencies? dependencies;
  final PaperCommentRepository? commentRepository;
  final PaperInteractionRepository? interactionRepository;
  final PaperPreferenceRepository? preferenceRepository;
  final PaperReadingRepository? readingRepository;
  final PaperSearchHistoryRepository? searchHistoryRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final PaperAiService? aiService;
  final PaperAiSessionRepository? aiSessionRepository;
  final PaperTranslationServiceFactory? translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final PaperAiService? webSearchAiService;

  @override
  State<PaperFlowApp> createState() => _PaperFlowAppState();
}

class _PaperFlowAppState extends State<PaperFlowApp> {
  late final PaperFlowDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ??
        PaperFlowDependencies.preview(
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
        title: 'PaperFlow',
        debugShowCheckedModeBanner: false,
        theme: PaperFlowTheme.light(),
        navigatorObservers: [PaperFlowRouteObserver.instance],
        home: _PaperFlowBootstrap(
          showSplash: widget.showSplash,
          dependencies: _dependencies,
        ),
      ),
    );
  }
}

class _PaperFlowBootstrap extends StatefulWidget {
  const _PaperFlowBootstrap({
    required this.showSplash,
    required this.dependencies,
  });

  final bool showSplash;
  final PaperFlowDependencies dependencies;

  @override
  State<_PaperFlowBootstrap> createState() => _PaperFlowBootstrapState();
}

class _PaperFlowBootstrapState extends State<_PaperFlowBootstrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late bool _splashComplete;

  @override
  void initState() {
    super.initState();
    _splashComplete = !widget.showSplash;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeInCubic),
        ),
        weight: 20,
      ),
    ]).animate(_controller);
    _scale = Tween(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.showSplash) {
      _controller
        ..addStatusListener(_handleAnimationStatus)
        ..forward();
    }
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
    if (_splashComplete) {
      return PaperFlowShell(
        dependencies: widget.dependencies,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'assets/images/paperflow_logo.png',
              width: 112,
              height: 112,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _splashComplete = true);
    }
  }
}

class PaperFlowShell extends StatefulWidget {
  const PaperFlowShell({
    super.key,
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

  final PaperFlowDependencies? dependencies;
  final PaperCommentRepository? commentRepository;
  final PaperInteractionRepository? interactionRepository;
  final PaperPreferenceRepository? preferenceRepository;
  final PaperReadingRepository? readingRepository;
  final PaperSearchHistoryRepository? searchHistoryRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final PaperAiService? aiService;
  final PaperAiSessionRepository? aiSessionRepository;
  final PaperTranslationServiceFactory? translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final PaperAiService? webSearchAiService;

  @override
  State<PaperFlowShell> createState() => _PaperFlowShellState();
}

class _PaperFlowShellState extends State<PaperFlowShell> {
  int _selectedIndex = 0;
  int _coveringRouteDepth = 0;
  late final PaperFlowDependencies _dependencies;
  late final PaperController _paperController;
  late final PaperCommentController _commentController;
  late final PaperReadingController _readingController;
  late final PaperAiService _paperAiService;
  late final PaperAiService _webSearchAiService;
  late final PaperAiService _mainAiService;
  late final PaperAiService _mainWebSearchAiService;
  late final PaperAiSessionRepository _aiSessionRepository;
  late final ChatSessionController _chatSessionController;
  late final PaperSearchHistoryRepository _searchHistoryRepository;
  late final PaperTranslationServiceFactory _translationServiceFactory;
  late final PaperLinkService _linkService;
  late final DeepSeekCredentialController _credentialController;
  late final LocalDataController _localDataController;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ??
        PaperFlowDependencies.preview(
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
      mainSessionId: MainAiChatDefinition.sessionId,
      contexts: _paperChatContexts,
    );
    unawaited(_chatSessionController.refresh());
    _translationServiceFactory = _dependencies.translationServiceFactory;
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
      backgroundColor: PaperFlowColors.canvas,
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
                  aiService: _paperAiService,
                  webSearchAiService: _webSearchAiService,
                  aiSessionRepository: _aiSessionRepository,
                  translationServiceFactory: _translationServiceFactory,
                  translationRepository: _dependencies.translationRepository,
                  shareService: _dependencies.shareService,
                  linkService: _linkService,
                  onSearch: _openPaperSearch,
                  onOpenPaperDetail: (paperId) =>
                      unawaited(_openPaperDetailById(paperId)),
                ),
                AiChatHomeScreen(
                  chatSessionController: _chatSessionController,
                  onOpenPaperChat: _openAiChatById,
                  onOpenMainChat: _openMainAiChat,
                ),
                ProfileScreen(
                  credentialController: _credentialController,
                  localDataController: _localDataController,
                  favoriteGroups: _paperController.interactions.favoriteGroups,
                  favoritePapersByGroup: {
                    for (final group
                        in _paperController.interactions.favoriteGroups)
                      group.id: _papersForIds(
                        _paperController.interactions.favoritePaperIds(
                          group.id,
                        ),
                      ),
                  },
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
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: PaperFlowBottomNav(
              selectedIndex: _selectedIndex,
              papersGridMode: _paperController.gridMode,
              onSelected: _handleNavigation,
            ),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(int index) {
    if (index == 0 && _selectedIndex == 0) {
      _paperController.toggleGridMode();
      return;
    }
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
      _paperController.feed.allPapers.map(
        (paper) => ChatContextSummary(id: paper.id, title: paper.title),
      );

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
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PaperAiChatScreen(
          chatContext: PaperChatContext.fromPaper(paper),
          aiService: _paperAiService,
          webSearchAiService: _webSearchAiService,
          sessionRepository: _aiSessionRepository,
        ),
      ),
    );
    await _chatSessionController.refresh();
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
          aiService: _paperAiService,
          webSearchAiService: _webSearchAiService,
          aiSessionRepository: _aiSessionRepository,
          translationServiceFactory: _translationServiceFactory,
          translationRepository: _dependencies.translationRepository,
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
