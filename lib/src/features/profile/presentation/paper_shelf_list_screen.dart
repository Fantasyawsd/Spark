import 'package:flutter/material.dart';

import '../../../core/theme/spark_design_tokens.dart';
import '../../../core/theme/spark_font_sizes.dart';
import '../../../core/theme/spark_theme.dart';
import '../../papers/papers.dart';

/// Full list page for favorites, read-later papers, and reading history.
class PaperShelfListScreen extends StatefulWidget {
  const PaperShelfListScreen.collection({
    super.key,
    required this.title,
    required this.groups,
    required this.papersByGroup,
    required this.onOpenPaper,
  })  : papers = const [],
        _grouped = true;

  const PaperShelfListScreen.flat({
    super.key,
    required this.title,
    required this.papers,
    required this.onOpenPaper,
  })  : groups = const [],
        papersByGroup = const {},
        _grouped = false;

  final String title;
  final List<FavoriteGroup> groups;
  final Map<String, List<Paper>> papersByGroup;
  final List<Paper> papers;
  final ValueChanged<String> onOpenPaper;
  final bool _grouped;

  @override
  State<PaperShelfListScreen> createState() => _PaperShelfListScreenState();
}

class _PaperShelfListScreenState extends State<PaperShelfListScreen> {
  String _selectedGroupId = defaultFavoriteGroupId;

  @override
  Widget build(BuildContext context) {
    final papers = widget._grouped
        ? (widget.papersByGroup[_selectedGroupId] ?? const <Paper>[])
        : widget.papers;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          style: TextStyle(
            color: SparkColors.of(context).ink,
            fontSize: SparkFontSizes.title,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget._grouped) _buildGroupChips(),
            Expanded(
              child: papers.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      key: const ValueKey('paper-shelf-list'),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                      itemCount: papers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _ShelfPaperRow(
                        paper: papers[index],
                        onTap: () => widget.onOpenPaper(papers[index].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final group = widget.groups[index];
          final selected = group.id == _selectedGroupId;
          final count = widget.papersByGroup[group.id]?.length ?? 0;
          return ChoiceChip(
            key: ValueKey('paper-shelf-group-${group.id}'),
            selected: selected,
            label: Text('${group.name} $count'),
            onSelected: (_) => setState(() {
              _selectedGroupId = group.id;
            }),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      key: const ValueKey('paper-shelf-empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            color: SparkColors.of(context).muted,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            widget._grouped ? '这个分组还是空的' : '还没有内容',
            style: TextStyle(
              color: SparkColors.of(context).ink,
              fontSize: SparkFontSizes.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfPaperRow extends StatelessWidget {
  const _ShelfPaperRow({required this.paper, required this.onTap});

  final Paper paper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
      child: InkWell(
        key: ValueKey('paper-shelf-row-${paper.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
            border: Border.all(color: SparkColors.of(context).line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paper.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SparkColors.of(context).ink,
                  fontSize: SparkFontSizes.body,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                paper.venue ??
                    paper.journalReference ??
                    (paper.source == 'arxiv' ? 'arXiv' : paper.source),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SparkColors.of(context).muted,
                  fontSize: SparkFontSizes.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
