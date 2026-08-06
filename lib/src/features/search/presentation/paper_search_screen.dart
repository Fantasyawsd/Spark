import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/spark_theme.dart';
import '../../papers/domain/paper.dart';
import '../application/paper_search_controller.dart';

class PaperSearchScreen extends StatefulWidget {
  const PaperSearchScreen({
    super.key,
    required this.controller,
    required this.onPaperSelected,
  });

  final PaperSearchController controller;
  final FutureOr<void> Function(String paperId) onPaperSelected;

  @override
  State<PaperSearchScreen> createState() => _PaperSearchScreenState();
}

class _PaperSearchScreenState extends State<PaperSearchScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    widget.controller.initialize();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              textController: _textController,
              onChanged: widget.controller.updateQuery,
              onSubmitted: widget.controller.submitQuery,
              onClear: _clearQuery,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final controller = widget.controller;
    if (controller.query.trim().isEmpty) {
      return _SearchHistory(
        loading: controller.loadingHistory,
        history: controller.history,
        error: controller.historyError,
        onSelected: _selectHistory,
        onRemoved: controller.removeHistory,
        onClear: controller.clearHistory,
      );
    }
    if (controller.loadingResults && controller.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.results.isEmpty) {
      return _NoSearchResults(message: controller.resultsError?.message);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 320 &&
            controller.hasMoreResults) {
          unawaited(controller.loadMoreResults());
        }
        return false;
      },
      child: ListView.separated(
        key: const ValueKey('paper-search-results'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount:
            controller.results.length + (controller.loadingMoreResults ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == controller.results.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final paper = controller.results[index];
          return _PaperSearchResult(
            paper: paper,
            onTap: () => _openPaper(paper.id),
          );
        },
      ),
    );
  }

  void _clearQuery() {
    _textController.clear();
    widget.controller.updateQuery('');
  }

  void _selectHistory(String value) {
    _textController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    widget.controller.submitQuery(value);
  }

  Future<void> _openPaper(String paperId) async {
    await widget.controller.rememberCurrentQuery();
    await widget.onPaperSelected(paperId);
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.textController,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController textController;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: TextField(
              key: const ValueKey('paper-search-field'),
              controller: textController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: '搜索标题、作者、会议、主题或 arXiv ID',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
                filled: true,
                fillColor: SparkColors.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _SearchHistory extends StatelessWidget {
  const _SearchHistory({
    required this.loading,
    required this.history,
    required this.error,
    required this.onSelected,
    required this.onRemoved,
    required this.onClear,
  });

  final bool loading;
  final List<String> history;
  final String? error;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemoved;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '搜索历史',
                style: TextStyle(
                  color: SparkColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (history.isNotEmpty)
              TextButton(onPressed: onClear, child: const Text('全部清除')),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: TextStyle(
                color: SparkColors.primary,
                fontSize: 11,
              ),
            ),
          ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 34),
            child: Center(
              child: Text(
                '暂无搜索历史',
                style: TextStyle(color: SparkColors.muted, fontSize: 12),
              ),
            ),
          )
        else
          for (final item in history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.history_rounded,
                color: SparkColors.muted,
                size: 20,
              ),
              title: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onSelected(item),
              trailing: IconButton(
                tooltip: '删除历史',
                onPressed: () => onRemoved(item),
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
            ),
      ],
    );
  }
}

class _PaperSearchResult extends StatelessWidget {
  const _PaperSearchResult({required this.paper, required this.onTap});

  final Paper paper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('paper-search-result-${paper.id}'),
      contentPadding: const EdgeInsets.symmetric(vertical: 7),
      onTap: onTap,
      title: Text(
        paper.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: SparkColors.ink,
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _searchResultSubtitle(paper),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: SparkColors.muted, fontSize: 11),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }

  String _searchResultSubtitle(Paper paper) {
    final venue = paper.venue ??
        paper.journalReference ??
        (paper.source == 'arxiv' ? 'arXiv' : paper.source);
    final topic = paper.contentKeywords.isNotEmpty
        ? paper.contentKeywords.first
        : (paper.primarySubject ??
            (paper.subjects.isNotEmpty ? paper.subjects.first : null));
    return [
      paper.firstAuthor,
      venue,
      if (topic != null) topic,
    ].join(' · ');
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('paper-search-empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              color: SparkColors.muted, size: 36),
          const SizedBox(height: 10),
          Text(
            message ?? '没有找到相关论文',
            style: const TextStyle(
              color: SparkColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
