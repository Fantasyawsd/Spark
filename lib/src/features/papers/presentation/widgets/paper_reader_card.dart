import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/platform/external_http_uri.dart';
import '../../../../core/platform/spark_clipboard.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/spark_segmented_control.dart';
import '../../../chat/chat.dart';
import '../../application/paper_translation_service.dart';
import '../../domain/paper.dart';
import '../../domain/paper_keyword_repository.dart';
import 'paper_action_bar.dart';
import 'paper_full_reader_page.dart';
import 'paper_metadata.dart';
import 'paper_pdf_button.dart';
import 'paper_related_papers.dart';
import 'paper_tab_body.dart';
import 'paper_translation_content.dart';
import 'paper_reader_card_lifecycle.dart';
import 'paper_reader_content.dart';

typedef PaperDiscussionOpener = void Function(List<String> keywords,
    {required bool keywordCacheFailed});

class PaperReaderCard extends StatefulWidget {
  const PaperReaderCard({
    super.key,
    required this.paper,
    required this.liked,
    required this.saved,
    required this.read,
    required this.readLater,
    required this.followed,
    required this.shareCountDelta,
    required this.commentCountDelta,
    required this.onLike,
    required this.onSave,
    required this.onSaveLongPress,
    required this.onToggleRead,
    required this.onToggleReadLater,
    required this.onFollow,
    required this.onComment,
    required this.onAnalyze,
    required this.onShare,
    required this.translationServiceFactory,
    required this.keywordService,
    this.active = true,
    this.initialAbstractScrollOffset = 0,
    this.onAbstractScrollChanged,
    this.translationRepository,
    this.keywordRepository,
    this.onOpenPaper,
    this.onOpenRelatedPaper,
    this.contentTopInset = 8,
    this.actionBarBottomInset = 72,
  });

  final Paper paper;
  final bool liked;
  final bool saved;
  final bool read;
  final bool readLater;
  final bool followed;
  final int shareCountDelta;
  final int commentCountDelta;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onSaveLongPress;
  final VoidCallback onToggleRead;
  final VoidCallback onToggleReadLater;
  final VoidCallback onFollow;
  final PaperDiscussionOpener onComment;
  final PaperDiscussionOpener onAnalyze;
  final VoidCallback onShare;
  final ValueChanged<Uri>? onOpenPaper;
  final ValueChanged<String>? onOpenRelatedPaper;
  final PaperTranslationServiceFactory translationServiceFactory;
  final ChatAiService keywordService;
  final PaperTranslationRepository? translationRepository;
  final PaperKeywordRepository? keywordRepository;
  final bool active;
  final double initialAbstractScrollOffset;
  final ValueChanged<double>? onAbstractScrollChanged;
  final double contentTopInset;
  final double actionBarBottomInset;

  @override
  State<PaperReaderCard> createState() => _PaperReaderCardState();
}

class _PaperReaderCardState extends State<PaperReaderCard> {
  static const _tabs = ['Abstract', '摘要', '关键词', '作者', '论文解读', '相关论文'];

  late int _tabIndex;
  late final PageController _tabPageController;
  late PaperReaderCardControllerSet _controllers;

  @override
  void initState() {
    super.initState();
    _tabIndex = 0;
    _tabPageController = PageController();
    _controllers = PaperReaderCardControllerSet(
      paper: widget.paper,
      translationServiceFactory: widget.translationServiceFactory,
      keywordService: widget.keywordService,
      translationRepository: widget.translationRepository,
      keywordRepository: widget.keywordRepository,
      onTranslationChanged: _handleTranslationChanged,
      onKeywordChanged: _handleKeywordChanged,
    );
  }

  @override
  void didUpdateWidget(covariant PaperReaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final update = _controllers.update(
      paper: widget.paper,
      translationServiceFactory: widget.translationServiceFactory,
      keywordService: widget.keywordService,
      translationRepository: widget.translationRepository,
      keywordRepository: widget.keywordRepository,
    );
    if (oldWidget.active && !widget.active) {
      _controllers.cancel();
    }
    if (update.paperChanged || (!oldWidget.active && widget.active)) {
      _resetToOriginal();
    }
    if (widget.active &&
        (update.paperChanged ||
            update.translationChanged ||
            update.keywordChanged ||
            !oldWidget.active)) {
      unawaited(_initializeCurrentTab());
    }
  }

  @override
  void dispose() {
    _tabPageController.dispose();
    _controllers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    final safePadding = MediaQuery.paddingOf(context);
    final hasPaperLink = widget.onOpenPaper != null &&
        (validExternalHttpUri(paper.pdfUrl) != null ||
            validExternalHttpUri(paper.paperUrl) != null);
    return ColoredBox(
      color: SparkColors.of(context).card,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                widget.contentTopInset,
                16,
                safePadding.bottom + widget.actionBarBottomInset + 96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MobileSelectableText(
                    key: ValueKey('paper-title-${paper.id}'),
                    text: paper.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    onTap: () => platformSparkClipboard.copyText(paper.title),
                    style: TextStyle(
                      color: SparkColors.of(context).ink,
                      fontSize: SparkFontSizes.headline,
                      height: 1.16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PaperMetadata(
                    paper: paper,
                    followed: widget.followed,
                    onFollow: widget.onFollow,
                  ),
                  if (hasPaperLink) ...[
                    const SizedBox(height: 3),
                    PaperPdfButton(paper: paper, onOpen: widget.onOpenPaper!),
                  ],
                  const SizedBox(height: 8),
                  SparkSegmentedControl(
                    key: const ValueKey('paper-tabs'),
                    tabs: _tabs,
                    selectedIndex: _tabIndex,
                    onSelected: _selectTab,
                  ),
                  const SizedBox(height: 11),
                  Expanded(
                    child: PageView.builder(
                      key: const ValueKey('paper-tab-pages'),
                      controller: _tabPageController,
                      itemCount: _tabs.length,
                      onPageChanged: _handleTabChanged,
                      itemBuilder: (context, index) =>
                          _buildTabContent(paper, index),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: safePadding.bottom + widget.actionBarBottomInset + 56,
            child: PaperReaderAiInterpretButton(
              onPressed: () => unawaited(_openDiscussion(widget.onAnalyze)),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: safePadding.bottom + widget.actionBarBottomInset,
            height: 52,
            child: PaperActionBar(
              paper: paper,
              liked: widget.liked,
              saved: widget.saved,
              shareCountDelta: widget.shareCountDelta,
              commentCountDelta: widget.commentCountDelta,
              onLike: widget.onLike,
              onComment: () => unawaited(_openDiscussion(widget.onComment)),
              onSave: widget.onSave,
              onSaveLongPress: widget.onSaveLongPress,
              onShare: widget.onShare,
              read: widget.read,
              readLater: widget.readLater,
              onToggleRead: widget.onToggleRead,
              onToggleReadLater: widget.onToggleReadLater,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTabChanged(int index) {
    setState(() => _tabIndex = index);
    unawaited(_initializeCurrentTab());
  }

  Future<void> _initializeCurrentTab() async {
    if (!mounted || !widget.active) return;
    if (_tabIndex == 1) {
      final controller = _controllers.translation;
      await controller.initialize();
      if (!mounted ||
          !widget.active ||
          _tabIndex != 1 ||
          !identical(controller, _controllers.translation)) {
        return;
      }
      await controller.ensureTranslated();
      return;
    }
    if (_tabIndex == 2) {
      await _controllers.keywords.initialize();
    }
  }

  void _resetToOriginal() {
    _tabIndex = 0;
    if (_tabPageController.hasClients) {
      _tabPageController.jumpToPage(0);
    }
  }

  void _selectTab(int index) {
    if (index == _tabIndex || !_tabPageController.hasClients) return;
    _tabPageController.animateToPage(
      index,
      duration: MotionTokens.duration(context, MotionTokens.tabDuration),
      curve: MotionTokens.pageCurve,
    );
  }

  Widget _buildTabContent(Paper paper, int index) {
    if (index == 1) {
      return PaperTranslationContent(
        key: ValueKey('${paper.id}-translation'),
        markdown: _controllers.translation.markdown,
        loadingCache: _controllers.translation.loadingCache,
        translating: _controllers.translation.translating,
        error: _controllers.translation.error,
        onRetry: _controllers.translation.translate,
        onRefresh: () => _controllers.translation.translate(force: true),
        onCancel: _controllers.translation.cancel,
        onExpand: () => _openFullReader(
          paper,
          _controllers.translation.markdown,
          title: '摘要',
        ),
      );
    }
    if (index == 2) {
      return PaperReaderKeywordContent(
        keywords: _controllers.keywords.keywords,
        loadingCache: _controllers.keywords.loadingCache,
        generating: _controllers.keywords.generating,
        error: _controllers.keywords.error,
        onGenerate: _controllers.keywords.generate,
        onRefresh: () => _controllers.keywords.generate(force: true),
        onCancel: _controllers.keywords.cancel,
      );
    }
    if (index == 3) {
      return PaperReaderAuthorContent(paper: paper);
    }
    if (index == 4) {
      return PaperReaderAiInterpretationContent(
        onOpen: () => unawaited(_openDiscussion(widget.onAnalyze)),
      );
    }
    if (index == 5) {
      return PaperRelatedPapers(
        key: ValueKey('${paper.id}-related-papers'),
        papers: paper.relatedPapers,
        topics: const [],
        onOpen: widget.onOpenRelatedPaper,
      );
    }
    return PaperTabBody(
      key: ValueKey('${paper.id}-tab-$index'),
      text: paper.content.originalAbstractMarkdown,
      expandable: true,
      topics: const [],
      onExpand: () => _openFullReader(
        paper,
        paper.content.originalAbstractMarkdown,
        title: 'Abstract',
      ),
    );
  }

  void _openFullReader(Paper paper, String markdown, {required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PaperFullReaderPage(
          paper: paper,
          markdown: markdown,
          title: title,
          initialScrollOffset:
              title == 'Abstract' ? widget.initialAbstractScrollOffset : 0,
          onScrollOffsetChanged:
              title == 'Abstract' ? widget.onAbstractScrollChanged : null,
        ),
      ),
    );
  }

  Future<void> _openDiscussion(PaperDiscussionOpener open) async {
    final controller = _controllers.keywords;
    await controller.initialize();
    if (!mounted ||
        !widget.active ||
        !identical(controller, _controllers.keywords)) {
      return;
    }
    open(
      controller.keywords,
      keywordCacheFailed:
          controller.cacheLoadFailed && controller.keywords.isEmpty,
    );
  }

  void _handleTranslationChanged() {
    if (mounted) setState(() {});
  }

  void _handleKeywordChanged() {
    if (mounted) setState(() {});
  }
}
