import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/paperflow_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/paperflow_bottom_nav.dart';
import '../features/chat/application/chat_session_controller.dart';
import '../features/chat/application/main_ai_chat_definition.dart';
import '../features/chat/presentation/ai_chat_home_screen.dart';
import '../features/chat/presentation/main_ai_chat_screen.dart';
import '../features/chat/presentation/paper_ai_chat_screen.dart';
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
import '../features/papers/presentation/papers_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/search/application/paper_search_controller.dart';
import '../features/search/domain/paper_search_history_repository.dart';
import '../features/search/presentation/paper_search_screen.dart';
import 'paperflow_dependencies.dart';

class PaperFlowApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final resolvedDependencies = dependencies ??
        PaperFlowDependencies.preview(
          commentRepository: commentRepository,
          interactionRepository: interactionRepository,
          preferenceRepository: preferenceRepository,
          readingRepository: readingRepository,
          searchHistoryRepository: searchHistoryRepository,
          shareService: shareService,
          linkService: linkService,
          aiService: aiService,
          webSearchAiService: webSearchAiService,
          aiSessionRepository: aiSessionRepository,
          translationServiceFactory: translationServiceFactory,
          translationRepository: translationRepository,
        );
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'PaperFlow',
        debugShowCheckedModeBanner: false,
        theme: PaperFlowTheme.light(),
        home: _PaperFlowBootstrap(
          showSplash: showSplash,
          dependencies: resolvedDependencies,
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
    )..addListener(_handlePaperStateChanged);
    unawaited(_paperController.initialize());
    _readingController = PaperReadingController(
      repository: _dependencies.readingRepository,
    )..addListener(_handleReadingStateChanged);
    unawaited(_readingController.initialize());
    _commentController = PaperCommentController(
      repository: _dependencies.commentRepository,
    );
    unawaited(
      _commentController.initialize(
        _paperController.feed.allPapers.map((paper) => paper.id),
      ),
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
                  active: _selectedIndex == 0,
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
                ),
                AiChatHomeScreen(
                  chatSessionController: _chatSessionController,
                  onOpenPaperChat: _openAiChatById,
                  onOpenMainChat: _openMainAiChat,
                ),
                ProfileScreen(
                  savedPapers: _paperController.feed.allPapers
                      .where(
                        (paper) =>
                            _paperController.interactions.isSaved(paper.id),
                      )
                      .toList(growable: false),
                  readingHistory: _papersForIds(
                    _readingController.historyPaperIds,
                  ),
                  readLaterPapers: _papersForIds(
                    _readingController.readLaterPaperIds,
                  ),
                  onOpenPaper: _openSavedPaper,
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

  List<Paper> _papersForIds(Iterable<String> ids) {
    final papersById = {
      for (final paper in _paperController.feed.allPapers) paper.id: paper,
    };
    return ids
        .map((id) => papersById[id])
        .whereType<Paper>()
        .toList(growable: false);
  }

  void _openPaperSearch() {
    final controller = PaperSearchController(
      papers: _paperController.feed.allPapers,
      historyRepository: _searchHistoryRepository,
    );
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (context) => PaperSearchScreen(
              controller: controller,
              onPaperSelected: _paperController.openPaperById,
            ),
          ),
        )
        .whenComplete(controller.dispose);
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

  void _openSavedPaper(String paperId) {
    _paperController.openPaperById(paperId);
    setState(() => _selectedIndex = 0);
  }
}
