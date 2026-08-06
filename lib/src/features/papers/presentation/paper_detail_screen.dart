import 'package:flutter/material.dart';

import '../../../core/navigation/spark_route_observer.dart';
import '../../../core/theme/spark_theme.dart';
import '../application/paper_ai_service.dart';
import '../application/paper_ai_session_repository.dart';
import '../application/paper_comment_controller.dart';
import '../application/paper_interaction_controller.dart';
import '../application/paper_keyword_service.dart';
import '../application/paper_link_service.dart';
import '../application/paper_reading_controller.dart';
import '../application/paper_share_service.dart';
import '../application/paper_translation_service.dart';
import '../domain/paper.dart';
import 'widgets/paper_reader_view.dart';

/// A focused paper reader pushed from search, profile, or a paper link.
///
/// The home feed owns category navigation and the app dock. This route only
/// owns the selected paper and deliberately leaves the feed position intact.
class PaperDetailScreen extends StatefulWidget {
  const PaperDetailScreen({
    super.key,
    required this.paper,
    required this.interactionController,
    required this.commentController,
    required this.readingController,
    required this.aiService,
    required this.keywordService,
    required this.translationServiceFactory,
    this.webSearchAiService,
    this.aiSessionRepository,
    this.translationRepository,
    this.keywordRepository,
    this.shareService,
    this.linkService,
    this.onOpenRelatedPaper,
  });

  final Paper paper;
  final PaperInteractionController interactionController;
  final PaperCommentController commentController;
  final PaperReadingController readingController;
  final PaperAiService aiService;
  final PaperAiService keywordService;
  final PaperAiService? webSearchAiService;
  final PaperAiSessionRepository? aiSessionRepository;
  final PaperTranslationServiceFactory translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final PaperKeywordRepository? keywordRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final ValueChanged<String>? onOpenRelatedPaper;

  @override
  State<PaperDetailScreen> createState() => _PaperDetailScreenState();
}

class _PaperDetailScreenState extends State<PaperDetailScreen> with RouteAware {
  PageRoute<dynamic>? _observedRoute;
  DateTime? _visibleSince;
  bool _openRecorded = false;
  bool _openRecordScheduled = false;
  int _lastInteractionErrorRevision = 0;

  Paper get _paper => widget.paper;
  PaperInteractionController get _interactions => widget.interactionController;

  @override
  void initState() {
    super.initState();
    _interactions.addListener(_handleStateChanged);
    widget.commentController.addListener(_handleStateChanged);
    widget.readingController.addListener(_handleStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic>) {
      _beginVisiblePeriod();
      return;
    }
    if (identical(route, _observedRoute)) return;
    final previousRoute = _observedRoute;
    if (previousRoute != null) {
      SparkRouteObserver.instance.unsubscribe(this);
    }
    _observedRoute = route;
    SparkRouteObserver.instance.subscribe(this, route);
  }

  @override
  void dispose() {
    if (_observedRoute != null) {
      SparkRouteObserver.instance.unsubscribe(this);
    }
    _finishVisiblePeriod();
    _interactions.removeListener(_handleStateChanged);
    widget.commentController.removeListener(_handleStateChanged);
    widget.readingController.removeListener(_handleStateChanged);
    super.dispose();
  }

  @override
  void didPush() => _beginVisiblePeriod();

  @override
  void didPushNext() => _finishVisiblePeriod();

  @override
  void didPopNext() => _beginVisiblePeriod();

  @override
  void didPop() => _finishVisiblePeriod();

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
      key: ValueKey('paper-detail-${_paper.id}'),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: PaperReaderView(
              paper: _paper,
              interactionController: _interactions,
              commentController: widget.commentController,
              readingController: widget.readingController,
              aiService: widget.aiService,
              keywordService: widget.keywordService,
              webSearchAiService: widget.webSearchAiService,
              aiSessionRepository: widget.aiSessionRepository,
              translationServiceFactory: widget.translationServiceFactory,
              translationRepository: widget.translationRepository,
              keywordRepository: widget.keywordRepository,
              shareService: widget.shareService,
              linkService: widget.linkService,
              onOpenRelatedPaper: widget.onOpenRelatedPaper,
              contentTopInset: safeTop + 58,
              actionBarBottomInset: 12,
            ),
          ),
          Positioned(
            left: 10,
            top: safeTop + 6,
            child: Material(
              color: Colors.white.withValues(alpha: 0.94),
              shape: const CircleBorder(),
              child: IconButton(
                key: const ValueKey('paper-detail-back'),
                tooltip: '返回',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                color: SparkColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStateChanged() {
    if (!mounted) return;
    setState(() {});
    _showInteractionErrorIfNeeded();
  }

  void _beginVisiblePeriod() {
    _visibleSince ??= DateTime.now();
    if (_openRecorded || _openRecordScheduled) return;
    _openRecordScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openRecordScheduled = false;
      if (!mounted || _openRecorded) return;
      _openRecorded = true;
      widget.readingController.recordOpened(_paper.id);
    });
  }

  void _finishVisiblePeriod() {
    final visibleSince = _visibleSince;
    if (visibleSince == null) return;
    _visibleSince = null;
    widget.readingController.addDwellTime(
      _paper.id,
      DateTime.now().difference(visibleSince),
    );
  }

  void _showInteractionErrorIfNeeded() {
    final revision = _interactions.errorRevision;
    final message = _interactions.persistenceError;
    if (message == null || revision <= _lastInteractionErrorRevision) return;
    _lastInteractionErrorRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
