import 'package:flutter/material.dart';

import '../../../../core/platform/spark_clipboard.dart';
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
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      widget.onScrollOffsetChanged?.call(_scrollController.offset);
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('paper-full-reader'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: SparkColors.ink,
            fontSize: SparkFontSizes.titleSmall,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '复制标题',
            onPressed: () => platformSparkClipboard.copyText(
              widget.paper.title,
            ),
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SelectionArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: SparkMarkdown(
              data: widget.markdown,
              styleSheet: paperReaderMarkdownStyle(),
            ),
          ),
        ),
      ),
    );
  }
}
