import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/paperflow_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/paperflow_bottom_nav.dart';
import '../core/widgets/paperflow_sheet.dart';
import '../features/chat/application/main_ai_chat_definition.dart';
import '../features/chat/presentation/main_ai_chat_screen.dart';
import '../features/chat/presentation/paper_ai_chat_screen.dart';
import '../features/community/presentation/community_screen.dart';
import '../features/messages/presentation/messages_screen.dart';
import '../features/papers/application/paper_ai_service.dart';
import '../features/papers/application/paper_ai_session_repository.dart';
import '../features/papers/application/paper_comment_controller.dart';
import '../features/papers/application/paper_controller.dart';
import '../features/papers/application/paper_link_service.dart';
import '../features/papers/application/paper_share_service.dart';
import '../features/papers/application/paper_translation_service.dart';
import '../features/papers/data/arxiv_seed_repository.dart';
import '../features/papers/data/deepseek_paper_ai_service.dart';
import '../features/papers/data/deepseek_paper_translation_service.dart';
import '../features/papers/data/deepseek_web_search_ai_service.dart';
import '../features/papers/data/in_memory_paper_ai_session_repository.dart';
import '../features/papers/domain/paper_comment_repository.dart';
import '../features/papers/domain/paper.dart';
import '../features/papers/domain/paper_interaction_repository.dart';
import '../features/papers/domain/paper_preference_repository.dart';
import '../features/papers/presentation/papers_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/search/application/paper_search_controller.dart';
import '../features/search/data/in_memory_paper_search_history_repository.dart';
import '../features/search/domain/paper_search_history_repository.dart';
import '../features/search/presentation/paper_search_screen.dart';

class PaperFlowApp extends StatelessWidget {
  const PaperFlowApp({
    super.key,
    this.showSplash = true,
    this.commentRepository,
    this.interactionRepository,
    this.preferenceRepository,
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
  final PaperCommentRepository? commentRepository;
  final PaperInteractionRepository? interactionRepository;
  final PaperPreferenceRepository? preferenceRepository;
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
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'PaperFlow',
        debugShowCheckedModeBanner: false,
        theme: PaperFlowTheme.light(),
        home: _PaperFlowBootstrap(
          showSplash: showSplash,
          commentRepository: commentRepository,
          interactionRepository: interactionRepository,
          preferenceRepository: preferenceRepository,
          searchHistoryRepository: searchHistoryRepository,
          shareService: shareService,
          linkService: linkService,
          aiService: aiService,
          aiSessionRepository: aiSessionRepository,
          translationServiceFactory: translationServiceFactory,
          translationRepository: translationRepository,
          webSearchAiService: webSearchAiService,
        ),
      ),
    );
  }
}

class _PaperFlowBootstrap extends StatefulWidget {
  const _PaperFlowBootstrap({
    required this.showSplash,
    required this.commentRepository,
    required this.interactionRepository,
    required this.preferenceRepository,
    required this.searchHistoryRepository,
    required this.shareService,
    required this.linkService,
    required this.aiService,
    required this.aiSessionRepository,
    required this.translationServiceFactory,
    required this.translationRepository,
    required this.webSearchAiService,
  });

  final bool showSplash;
  final PaperCommentRepository? commentRepository;
  final PaperInteractionRepository? interactionRepository;
  final PaperPreferenceRepository? preferenceRepository;
  final PaperSearchHistoryRepository? searchHistoryRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final PaperAiService? aiService;
  final PaperAiSessionRepository? aiSessionRepository;
  final PaperTranslationServiceFactory? translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final PaperAiService? webSearchAiService;

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
        commentRepository: widget.commentRepository,
        interactionRepository: widget.interactionRepository,
        preferenceRepository: widget.preferenceRepository,
        searchHistoryRepository: widget.searchHistoryRepository,
        shareService: widget.shareService,
        linkService: widget.linkService,
        aiService: widget.aiService,
        aiSessionRepository: widget.aiSessionRepository,
        translationServiceFactory: widget.translationServiceFactory,
        translationRepository: widget.translationRepository,
        webSearchAiService: widget.webSearchAiService,
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
    this.commentRepository,
    this.interactionRepository,
    this.preferenceRepository,
    this.searchHistoryRepository,
    this.shareService,
    this.linkService,
    this.aiService,
    this.aiSessionRepository,
    this.translationServiceFactory,
    this.translationRepository,
    this.webSearchAiService,
  });

  final PaperCommentRepository? commentRepository;
  final PaperInteractionRepository? interactionRepository;
  final PaperPreferenceRepository? preferenceRepository;
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
  late final PaperController _paperController;
  late final PaperCommentController _commentController;
  late final PaperAiService _paperAiService;
  late final PaperAiService _webSearchAiService;
  late final PaperAiService _mainAiService;
  late final PaperAiService _mainWebSearchAiService;
  late final PaperAiSessionRepository _aiSessionRepository;
  late final PaperSearchHistoryRepository _searchHistoryRepository;
  late final PaperTranslationServiceFactory _translationServiceFactory;
  late final PaperLinkService _linkService;

  @override
  void initState() {
    super.initState();
    _paperController = PaperController(
      const ArxivSeedRepository(),
      interactionRepository: widget.interactionRepository,
      preferenceRepository: widget.preferenceRepository,
    )..addListener(_handlePaperStateChanged);
    unawaited(_paperController.initialize());
    _commentController = PaperCommentController(
      repository: widget.commentRepository,
    );
    unawaited(
      _commentController.initialize(
        _paperController.feed.allPapers.map((paper) => paper.id),
      ),
    );
    _paperAiService = widget.aiService ?? DeepSeekPaperAiService();
    _webSearchAiService =
        widget.webSearchAiService ?? DeepSeekWebSearchAiService();
    _mainAiService = DeepSeekPaperAiService(
      systemPromptBuilder: (_) => MainAiChatDefinition.systemPrompt(),
    );
    _mainWebSearchAiService = DeepSeekWebSearchAiService(
      systemPromptBuilder: (_) =>
          MainAiChatDefinition.systemPrompt(webSearch: true),
    );
    _aiSessionRepository =
        widget.aiSessionRepository ?? InMemoryPaperAiSessionRepository();
    _translationServiceFactory = widget.translationServiceFactory ??
        const DeepSeekPaperTranslationServiceFactory();
    _searchHistoryRepository = widget.searchHistoryRepository ??
        InMemoryPaperSearchHistoryRepository();
    _linkService = widget.linkService ?? const PlatformPaperLinkService();
  }

  @override
  void dispose() {
    _paperController
      ..removeListener(_handlePaperStateChanged)
      ..dispose();
    _commentController.dispose();
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
                  feedController: _paperController.feed,
                  interactionController: _paperController.interactions,
                  commentController: _commentController,
                  aiService: _paperAiService,
                  webSearchAiService: _webSearchAiService,
                  aiSessionRepository: _aiSessionRepository,
                  translationServiceFactory: _translationServiceFactory,
                  translationRepository: widget.translationRepository,
                  shareService: widget.shareService,
                  linkService: _linkService,
                  onSearch: _openPaperSearch,
                ),
                CommunityScreen(),
                MessagesScreen(
                  aiSessionRepository: _aiSessionRepository,
                  papers: _paperController.feed.allPapers,
                  onOpenAiChat: _openAiChat,
                  onOpenMainAiChat: _openMainAiChat,
                ),
                ProfileScreen(
                  savedPapers: _paperController.feed.allPapers
                      .where(
                        (paper) =>
                            _paperController.interactions.isSaved(paper.id),
                      )
                      .toList(growable: false),
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
              onCreate: () => _showCreateSheet(context),
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
    if (mounted) setState(() {});
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

  Future<void> _openAiChat(PaperRecord paper) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PaperAiChatScreen(
          paper: paper,
          aiService: _paperAiService,
          webSearchAiService: _webSearchAiService,
          sessionRepository: _aiSessionRepository,
        ),
      ),
    );
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
  }

  void _openSavedPaper(String paperId) {
    _paperController.openPaperById(paperId);
    setState(() => _selectedIndex = 0);
  }

  void _showCreateSheet(BuildContext context) {
    showPaperFlowSheet<void>(
      context: context,
      builder: (context) => Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PaperFlowColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '创建内容',
                style: TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _CreateAction(
                      icon: Icons.upload_file_rounded,
                      label: '上传论文',
                      color: PaperFlowColors.primary,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CreateAction(
                      icon: Icons.edit_note_rounded,
                      label: '发布动态',
                      color: PaperFlowColors.purple,
                      onTap: () => Navigator.pop(context),
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

class _CreateAction extends StatelessWidget {
  const _CreateAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: PaperFlowColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
