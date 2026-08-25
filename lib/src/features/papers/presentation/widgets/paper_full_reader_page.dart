import 'package:flutter/material.dart';

import '../../../../core/platform/spark_clipboard.dart';
import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/spark_markdown.dart';
import '../../domain/paper.dart';

class PaperFullReaderPage extends StatefulWidget {
  const PaperFullReaderPage({
    super.key,
    required this.paper,
    required this.markdown,
    required this.title,
    this.initialScrollOffset = 0,
    this.onScrollOffsetChanged,
  });

  final Paper paper;
  final String markdown;
  final String title;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollOffsetChanged;

  @override
  State<PaperFullReaderPage> createState() => _PaperFullReaderPageState();
}

class _PaperFullReaderPageState extends State<PaperFullReaderPage> {
  /// 字号档位对应的正文字号（基准 17 = SparkFontSizes.title）。
  static const List<double> _fontSteps = [15, 17, 19];

  late final ScrollController _scrollController;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  double _fontSize = 17;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );
    _scrollController.addListener(_updateProgress);
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      widget.onScrollOffsetChanged?.call(_scrollController.offset);
    }
    _scrollController.removeListener(_updateProgress);
    _scrollController.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final value = maxExtent <= 0
        ? 0.0
        : (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
    _progress.value = value;
  }

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    // 正文基准 17px；SparkMarkdown 内部文本随 MediaQuery textScaler 缩放。
    final textScaler = TextScaler.linear(_fontSize / SparkFontSizes.title);
    return Scaffold(
      key: const ValueKey('paper-full-reader'),
      backgroundColor: palette.card,
      appBar: AppBar(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.ink,
            fontSize: SparkFontSizes.titleSmall,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<double>(
            tooltip: '字号',
            onSelected: (value) => setState(() => _fontSize = value),
            icon: const Icon(Icons.format_size_outlined),
            itemBuilder: (context) => [
              for (final step in _fontSteps)
                CheckedPopupMenuItem<double>(
                  value: step,
                  checked: step == _fontSize,
                  child: Text('正文字号 ${step.round()}'),
                ),
            ],
          ),
          IconButton(
            tooltip: '复制标题',
            onPressed: () =>
                platformSparkClipboard.copyText(widget.paper.title),
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              top: false,
              child: SelectionArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    SparkDesignTokens.space4,
                    8,
                    SparkDesignTokens.space4,
                    28,
                  ),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: textScaler),
                    child: SparkMarkdown(
                      data: widget.markdown,
                      styleSheet: paperReaderMarkdownStyle(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 2,
              backgroundColor: palette.line,
              color: palette.primary,
            ),
          ),
        ],
      ),
    );
  }
}
