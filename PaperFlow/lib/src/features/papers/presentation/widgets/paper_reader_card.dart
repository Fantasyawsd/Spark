import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/paperflow_segmented_control.dart';
import '../../application/paper_link_service.dart';
import '../../application/paper_translation_controller.dart';
import '../../application/paper_translation_service.dart';
import '../../domain/paper.dart';
import 'paper_action_bar.dart';
import 'paper_full_reader_page.dart';
import 'paper_metadata.dart';
import 'paper_pdf_button.dart';
import 'paper_related_papers.dart';
import 'paper_tab_body.dart';
import 'paper_translation_content.dart';

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
    this.active = true,
    this.initialAbstractScrollOffset = 0,
    this.onAbstractScrollChanged,
    this.translationRepository,
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
  final VoidCallback onComment;
  final VoidCallback onAnalyze;
  final VoidCallback onShare;
  final ValueChanged<Uri>? onOpenPaper;
  final ValueChanged<String>? onOpenRelatedPaper;
  final PaperTranslationServiceFactory translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final bool active;
  final double initialAbstractScrollOffset;
  final ValueChanged<double>? onAbstractScrollChanged;
  final double contentTopInset;
  final double actionBarBottomInset;

  @override
  State<PaperReaderCard> createState() => _PaperReaderCardState();
}

class _PaperReaderCardState extends State<PaperReaderCard> {
  static const _tabs = ['原文', '中文解读', '相关论文'];

  late int _tabIndex;
  late final PageController _tabPageController;
  late PaperTranslationController _translationController;

  @override
  void initState() {
    super.initState();
    _tabIndex = 0;
    _tabPageController = PageController();
    _createTranslationController();
  }

  @override
  void didUpdateWidget(covariant PaperReaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final paperChanged = oldWidget.paper.id != widget.paper.id;
    final translationDependencyChanged = !identical(
          oldWidget.translationServiceFactory,
          widget.translationServiceFactory,
        ) ||
        !identical(
          oldWidget.translationRepository,
          widget.translationRepository,
        );
    if (paperChanged || translationDependencyChanged) {
      _translationController
        ..removeListener(_handleTranslationChanged)
        ..dispose();
      _createTranslationController();
    }
    if (paperChanged || (!oldWidget.active && widget.active)) {
      _resetToOriginal();
    }
  }

  @override
  void dispose() {
    _tabPageController.dispose();
    _translationController
      ..removeListener(_handleTranslationChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    final safePadding = MediaQuery.paddingOf(context);
    final hasPaperLink = widget.onOpenPaper != null &&
        (validPaperUri(paper.pdfUrl) != null ||
            validPaperUri(paper.paperUrl) != null);
    return ColoredBox(
      color: Colors.white,
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
                    onTap: () => Clipboard.setData(
                      ClipboardData(text: paper.title),
                    ),
                    style: const TextStyle(
                      color: PaperFlowColors.ink,
                      fontSize: 21,
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
                    PaperPdfButton(
                      paper: paper,
                      onOpen: widget.onOpenPaper!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  PaperFlowSegmentedControl(
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
            child: _AiInterpretButton(onPressed: widget.onAnalyze),
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
              onComment: widget.onComment,
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
    if (index == 1) _translationController.ensureTranslated();
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
        markdown: _translationController.markdown,
        loadingCache: _translationController.loadingCache,
        translating: _translationController.translating,
        error: _translationController.error,
        onRetry: _translationController.translate,
        onRefresh: () => _translationController.translate(force: true),
        onCancel: _translationController.cancel,
        onExpand: () => _openFullReader(
          paper,
          _translationController.markdown,
          title: '中文解读',
        ),
      );
    }
    if (index == 2) {
      return PaperRelatedPapers(
        key: ValueKey('${paper.id}-related-papers'),
        papers: paper.relatedPapers,
        topics: paper.topics,
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
        title: '原文摘要',
      ),
    );
  }

  void _openFullReader(
    Paper paper,
    String markdown, {
    required String title,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PaperFullReaderPage(
          paper: paper,
          markdown: markdown,
          title: title,
          initialScrollOffset:
              title == '原文摘要' ? widget.initialAbstractScrollOffset : 0,
          onScrollOffsetChanged:
              title == '原文摘要' ? widget.onAbstractScrollChanged : null,
        ),
      ),
    );
  }

  void _createTranslationController() {
    _translationController = PaperTranslationController(
      paper: widget.paper,
      service: widget.translationServiceFactory.create(),
      repository: widget.translationRepository,
    )..addListener(_handleTranslationChanged);
    _translationController.initialize();
  }

  void _handleTranslationChanged() {
    if (mounted) setState(() {});
  }
}

class _AiInterpretButton extends StatelessWidget {
  const _AiInterpretButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('paper-ai-entry'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: PaperFlowColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: const Text(
        'AI 解读',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class MobileSelectableText extends StatelessWidget {
  const MobileSelectableText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.onTap,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    if (mobile) {
      return SelectableText(
        text,
        maxLines: maxLines,
        style: style,
        onTap: onTap,
      );
    }
    final child = Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
