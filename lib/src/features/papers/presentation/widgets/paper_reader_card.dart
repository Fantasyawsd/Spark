import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/platform/external_http_uri.dart';
import '../../../../core/platform/spark_clipboard.dart';
import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/spark_segmented_control.dart';
import '../../../chat/chat.dart';
import '../../application/paper_keyword_controller.dart';
import '../../application/paper_translation_controller.dart';
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
  late PaperTranslationController _translationController;
  late PaperKeywordController _keywordController;

  @override
  void initState() {
    super.initState();
    _tabIndex = 0;
    _tabPageController = PageController();
    _createTranslationController();
    _createKeywordController();
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
    final keywordDependencyChanged =
        !identical(oldWidget.keywordService, widget.keywordService) ||
            !identical(oldWidget.keywordRepository, widget.keywordRepository);
    if (paperChanged || keywordDependencyChanged) {
      _keywordController
        ..removeListener(_handleKeywordChanged)
        ..dispose();
      _createKeywordController();
    }
    if (oldWidget.active && !widget.active) {
      _translationController.cancel();
      _keywordController.cancel();
    }
    if (paperChanged || (!oldWidget.active && widget.active)) {
      _resetToOriginal();
    }
    if (widget.active &&
        (paperChanged ||
            translationDependencyChanged ||
            keywordDependencyChanged ||
            !oldWidget.active)) {
      unawaited(_initializeCurrentTab());
    }
  }

  @override
  void dispose() {
    _tabPageController.dispose();
    _translationController
      ..removeListener(_handleTranslationChanged)
      ..dispose();
    _keywordController
      ..removeListener(_handleKeywordChanged)
      ..dispose();
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
            child: _AiInterpretButton(
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
      final controller = _translationController;
      await controller.initialize();
      if (!mounted ||
          !widget.active ||
          _tabIndex != 1 ||
          !identical(controller, _translationController)) {
        return;
      }
      await controller.ensureTranslated();
      return;
    }
    if (_tabIndex == 2) {
      await _keywordController.initialize();
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
          title: '摘要',
        ),
      );
    }
    if (index == 2) {
      return _KeywordContent(
        keywords: _keywordController.keywords,
        loadingCache: _keywordController.loadingCache,
        generating: _keywordController.generating,
        error: _keywordController.error,
        onGenerate: _keywordController.generate,
        onRefresh: () => _keywordController.generate(force: true),
        onCancel: _keywordController.cancel,
      );
    }
    if (index == 3) {
      return _AuthorContent(paper: paper);
    }
    if (index == 4) {
      return _AiInterpretationContent(
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
    final controller = _keywordController;
    await controller.initialize();
    if (!mounted ||
        !widget.active ||
        !identical(controller, _keywordController)) {
      return;
    }
    open(
      controller.keywords,
      keywordCacheFailed:
          controller.cacheLoadFailed && controller.keywords.isEmpty,
    );
  }

  void _createTranslationController() {
    _translationController = PaperTranslationController(
      paper: widget.paper,
      service: widget.translationServiceFactory.create(),
      repository: widget.translationRepository,
    )..addListener(_handleTranslationChanged);
  }

  void _createKeywordController() {
    _keywordController = PaperKeywordController(
      paper: widget.paper,
      service: widget.keywordService,
      repository: widget.keywordRepository,
    )..addListener(_handleKeywordChanged);
  }

  void _handleTranslationChanged() {
    if (mounted) setState(() {});
  }

  void _handleKeywordChanged() {
    if (mounted) setState(() {});
  }
}

class _KeywordContent extends StatelessWidget {
  const _KeywordContent({
    required this.keywords,
    required this.loadingCache,
    required this.generating,
    required this.error,
    required this.onGenerate,
    required this.onRefresh,
    required this.onCancel,
  });

  final List<String> keywords;
  final bool loadingCache;
  final bool generating;
  final String? error;
  final VoidCallback onGenerate;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (loadingCache && keywords.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (keywords.isEmpty) {
      return _ReaderEmptyState(
        icon: Icons.key_rounded,
        title: generating ? '正在生成关键词…' : '尚未生成关键词',
        message: error ?? '关键词将从论文标题和 Abstract 中提取。',
        actionLabel: generating
            ? '停止'
            : error == null
                ? '生成'
                : '重试',
        onAction: generating ? onCancel : onGenerate,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('paper-keyword-refresh'),
            onPressed: generating ? onCancel : onRefresh,
            child: Text(generating ? '停止' : '重新生成'),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: SparkDesignTokens.space2),
            child: Text(
              error!,
              style: TextStyle(
                color: SparkColors.of(context).danger,
                fontSize: SparkFontSizes.footnote,
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final keyword in keywords) Chip(label: Text(keyword)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthorContent extends StatelessWidget {
  const _AuthorContent({required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: paper.authors.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline_rounded),
        title: Text(paper.authors[index]),
      ),
    );
  }
}

class _AiInterpretationContent extends StatelessWidget {
  const _AiInterpretationContent({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _ReaderEmptyState(
      icon: Icons.auto_awesome_rounded,
      title: '围绕当前论文提问',
      message: '当前对话基于论文元数据和摘要，不包含 PDF 全文。',
      actionLabel: '打开 ChatPaper',
      onAction: onOpen,
    );
  }
}

class _ReaderEmptyState extends StatelessWidget {
  const _ReaderEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SparkDesignTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: SparkColors.of(context).muted, size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SparkColors.of(context).muted,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
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
        backgroundColor: SparkColors.of(context).primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(
          horizontal: SparkDesignTokens.space3,
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: const Text(
        'AI 解读',
        style: TextStyle(
          fontSize: SparkFontSizes.footnote,
          fontWeight: FontWeight.w800,
        ),
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
