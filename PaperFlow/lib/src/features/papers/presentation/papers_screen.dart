import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/motion/motion_tokens.dart';
import '../../../core/theme/paperflow_theme.dart';
import '../../../core/widgets/paperflow_tab_bar.dart';
import '../../../core/widgets/topic_chip.dart';
import '../application/paper_controller.dart';
import '../data/demo_paper_repository.dart';
import '../domain/paper.dart';
import 'paper_accent.dart';
import 'widgets/paper_action_bar.dart';
import 'widgets/paper_comments_sheet.dart';

class PapersScreen extends StatefulWidget {
  const PapersScreen({
    super.key,
    this.controller,
  });

  final PaperController? controller;

  @override
  State<PapersScreen> createState() => _PapersScreenState();
}

class _PapersScreenState extends State<PapersScreen> {
  late final PaperController _controller;
  late final PageController _pageController;
  late final bool _ownsController;

  static const _availableCategories = [
    'AI Agent',
    '多模态',
    '强化学习',
    '机器人',
    '语音',
    '推荐系统',
    '数据挖掘',
    'AI 安全',
  ];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? PaperController(const DemoPaperRepository());
    _pageController = PageController(
      initialPage: _controller.currentPaperIndex,
    );
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final papers = _controller.papers;
    return ColoredBox(
      color: PaperFlowColors.canvas,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: MotionTokens.duration(
                context,
                MotionTokens.pageDuration,
              ),
              switchInCurve: MotionTokens.enterCurve,
              switchOutCurve: MotionTokens.exitCurve,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.985, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: _controller.gridMode
                  ? MasonryGridView.count(
                      key: const ValueKey('paper-grid'),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        MediaQuery.paddingOf(context).top + 64,
                        12,
                        80,
                      ),
                      itemCount: papers.length,
                      itemBuilder: (context, index) => _PaperGridCard(
                        paper: papers[index],
                        index: index,
                        liked: _controller.isLiked(papers[index].id),
                        saved: _controller.isSaved(papers[index].id),
                        onOpen: () => _openPaper(index),
                        onLike: () => _controller.toggleLike(papers[index].id),
                        onSave: () => _controller.toggleSave(papers[index].id),
                      ),
                    )
                  : PageView.builder(
                      key: const ValueKey('paper-feed'),
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: papers.length,
                      onPageChanged: _controller.selectPaper,
                      itemBuilder: (context, index) => _PaperCard(
                        paper: papers[index],
                        index: index,
                        liked: _controller.isLiked(papers[index].id),
                        saved: _controller.isSaved(papers[index].id),
                        onLike: () => _controller.toggleLike(papers[index].id),
                        onSave: () => _controller.toggleSave(papers[index].id),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _PapersHeader(
                categories: _controller.categories,
                selectedIndex: _controller.categoryIndex,
                onSelected: _controller.selectCategory,
                onAddCategory: _showCategoryPicker,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPaper(int index) {
    _controller.openPaper(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  Future<void> _showCategoryPicker() async {
    final draft = _controller.extraCategories.toSet();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PaperFlowColors.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '选择主题',
                      style: TextStyle(
                        color: PaperFlowColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableCategories.map((category) {
                        final selected = draft.contains(category);
                        return FilterChip(
                          label: Text(category),
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (value) {
                            setSheetState(() {
                              if (value) {
                                draft.add(category);
                              } else {
                                draft.remove(category);
                              }
                            });
                          },
                          selectedColor: PaperFlowColors.primarySoft,
                          backgroundColor: PaperFlowColors.canvas,
                          side: BorderSide(
                            color: selected
                                ? PaperFlowColors.primary
                                : PaperFlowColors.line,
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? PaperFlowColors.primary
                                : PaperFlowColors.ink,
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          _availableCategories
                              .where(draft.contains)
                              .toList(growable: false),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: PaperFlowColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '完成',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    _controller.setExtraCategories(result);
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }
}

class _PapersHeader extends StatelessWidget {
  const _PapersHeader({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAddCategory,
  });

  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 25),
                itemBuilder: (context, index) {
                  if (index == categories.length) {
                    return Align(
                      alignment: Alignment.center,
                      child: IconButton(
                        tooltip: '添加主题',
                        visualDensity: VisualDensity.compact,
                        onPressed: onAddCategory,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: PaperFlowColors.muted,
                          size: 23,
                        ),
                      ),
                    );
                  }
                  final selected = selectedIndex == index;
                  return InkWell(
                    onTap: () => onSelected(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          categories[index],
                          style: TextStyle(
                            color: selected
                                ? PaperFlowColors.ink
                                : PaperFlowColors.muted,
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                            // 中英文统一到同一 CJK 字体，避免 Roboto 与中文
                            // fallback 字体的行高/基线差异造成的视觉错位。
                            fontFamily: PaperFlowTheme.platformCjkFontFamily(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: selected ? 24 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: PaperFlowColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          IconButton(
            tooltip: '搜索',
            visualDensity: VisualDensity.compact,
            onPressed: () {},
            icon: const Icon(Icons.search_rounded, size: 25),
          ),
        ],
      ),
    );
  }
}

class _PaperGridCard extends StatefulWidget {
  const _PaperGridCard({
    required this.paper,
    required this.index,
    required this.liked,
    required this.saved,
    required this.onOpen,
    required this.onLike,
    required this.onSave,
  });

  final PaperRecord paper;
  final int index;
  final bool liked;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback onSave;

  @override
  State<_PaperGridCard> createState() => _PaperGridCardState();
}

class _PaperGridCardState extends State<_PaperGridCard> {
  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: PaperFlowColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F15213A),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    paper.accent.color.withValues(alpha: 0.22),
                    paper.accent.color.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        color: paper.accent.color,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          paper.venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: paper.accent.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: widget.index.isEven ? 16 : 24),
                  Text(
                    paper.title,
                    maxLines: widget.index.isEven ? 4 : 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PaperFlowColors.ink,
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      const Icon(
                        Icons.format_quote_rounded,
                        color: PaperFlowColors.muted,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '被引 ${paper.citations}',
                        style: const TextStyle(
                          color: PaperFlowColors.muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper.authors,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PaperFlowColors.muted,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 9),
                  TopicChip(label: paper.topics.first, compact: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onLike,
                        child: Icon(
                          widget.liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: widget.liked
                              ? PaperFlowColors.primary
                              : PaperFlowColors.muted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        paper.likes,
                        style: const TextStyle(
                          color: PaperFlowColors.muted,
                          fontSize: 9.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onSave,
                        child: Icon(
                          widget.saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: widget.saved
                              ? PaperFlowColors.primary
                              : PaperFlowColors.muted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperCard extends StatefulWidget {
  const _PaperCard({
    required this.paper,
    required this.index,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
  });

  final PaperRecord paper;
  final int index;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;

  @override
  State<_PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends State<_PaperCard> {
  int _tabIndex = 0;
  bool _abstractExpanded = false;
  late final PageController _tabPageController;

  static const _tabs = ['摘要', '中文摘要', '相关论文'];

  @override
  void initState() {
    super.initState();
    _tabPageController = PageController();
  }

  @override
  void dispose() {
    _tabPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    final safePadding = MediaQuery.paddingOf(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            paper.accent.color.withValues(alpha: 0.025),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                safePadding.top + 116,
                16,
                safePadding.bottom + 134,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MobileSelectableText(
                    text: '${paper.venue} · 被引 ${paper.citations}',
                    style: TextStyle(
                      color: PaperFlowColors.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _MobileSelectableText(
                    key: ValueKey('paper-title-${paper.id}'),
                    text: paper.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    onTap: () => _copyTitle(paper.title),
                    style: const TextStyle(
                      color: PaperFlowColors.ink,
                      fontSize: 21,
                      height: 1.16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _MobileSelectableText(
                    text:
                        '${_compactAuthors(paper.authors)} · ${paper.firstAffiliation}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PaperFlowColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final topic in paper.topics)
                        TopicChip(label: topic, compact: true),
                    ],
                  ),
                  const SizedBox(height: 7),
                  PaperFlowTabBar(
                    key: const ValueKey('paper-tabs'),
                    tabs: _tabs,
                    selectedIndex: _tabIndex,
                    pageController: _tabPageController,
                    onSelected: _selectTab,
                  ),
                  const SizedBox(height: 9),
                  Expanded(
                    child: PageView.builder(
                      key: const ValueKey('paper-tab-pages'),
                      controller: _tabPageController,
                      itemCount: _tabs.length,
                      onPageChanged: (index) => setState(() {
                        _tabIndex = index;
                        _abstractExpanded = false;
                      }),
                      itemBuilder: (context, index) => _PaperTabBody(
                        key: ValueKey('${paper.id}-tab-$index'),
                        text: _tabText(paper, index),
                        expandable: index == 0,
                        expanded: index == 0 && _abstractExpanded,
                        onExpand: () =>
                            setState(() => _abstractExpanded = true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: safePadding.bottom + 74,
            height: 52,
            child: PaperActionBar(
              paper: paper,
              liked: widget.liked,
              saved: widget.saved,
              onLike: widget.onLike,
              onComment: () => showPaperCommentsSheet(context, paper),
              onSave: widget.onSave,
              onShare: () {},
              onAnalyze: () => showPaperCommentsSheet(
                context,
                paper,
                initialPage: PaperSheetPage.ai,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _compactAuthors(String authors) {
    final names = authors.split(',').map((name) => name.trim()).toList();
    if (names.length <= 1) return authors;
    return '${names.first} 等';
  }

  void _copyTitle(String title) {
    Clipboard.setData(ClipboardData(text: title));
  }

  void _selectTab(int index) {
    if (index == _tabIndex || !_tabPageController.hasClients) return;
    _tabPageController.animateToPage(
      index,
      duration: MotionTokens.duration(context, MotionTokens.tabDuration),
      curve: MotionTokens.pageCurve,
    );
  }

  String _tabText(PaperRecord paper, int index) {
    return switch (index) {
      0 => paper.abstractText,
      1 => paper.chineseAbstractMarkdown,
      _ => paper.relatedPapersMarkdown,
    };
  }
}

class _PaperTabBody extends StatelessWidget {
  const _PaperTabBody({
    super.key,
    required this.text,
    required this.expandable,
    required this.expanded,
    required this.onExpand,
  });

  final String text;
  final bool expandable;
  final bool expanded;
  final VoidCallback onExpand;

  static const _textStyle = TextStyle(
    color: PaperFlowColors.ink,
    fontSize: 17,
    height: 1.58,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final plainText = _plainText(text);
        final painter = TextPainter(
          text: TextSpan(text: plainText, style: _textStyle),
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final hasOverflow =
            expandable && painter.height > constraints.maxHeight;

        if (!hasOverflow && !expanded) {
          return _PaperMarkdown(data: text);
        }

        if (!expandable || expanded) {
          return SingleChildScrollView(
            key: const ValueKey('paper-tab-scroll'),
            padding: const EdgeInsets.only(bottom: 12),
            physics: const ClampingScrollPhysics(),
            child: _PaperMarkdown(data: text),
          );
        }

        const buttonHeight = 34.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                  stops: [0.82, 1],
                ).createShader(rect),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _PaperMarkdown(data: text),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onExpand,
                style: TextButton.styleFrom(
                  foregroundColor: PaperFlowColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, buttonHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                label: const Text(
                  '展开全文',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _plainText(String markdown) {
    return markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' code ')
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'^[#>*+\-]+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'[*_~]'), '');
  }
}

class _PaperMarkdown extends StatelessWidget {
  const _PaperMarkdown({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: _PaperTabBody._textStyle,
        h1: _PaperTabBody._textStyle.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        h2: _PaperTabBody._textStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        h3: _PaperTabBody._textStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        listBullet: _PaperTabBody._textStyle,
        strong: const TextStyle(fontWeight: FontWeight.w700),
        blockSpacing: 10,
        listIndent: 22,
      ),
    );
  }
}

class _MobileSelectableText extends StatelessWidget {
  const _MobileSelectableText({
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
