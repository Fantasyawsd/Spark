import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../domain/paper.dart';
import 'paper_markdown.dart';

class PaperFullReaderPage extends StatefulWidget {
  const PaperFullReaderPage({
    super.key,
    required this.paper,
    required this.markdown,
    required this.title,
    this.initialScrollOffset = 0,
    this.onScrollOffsetChanged,
  });

  final PaperRecord paper;
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
            color: PaperFlowColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '复制标题',
            onPressed: () => Clipboard.setData(
              ClipboardData(text: widget.paper.title),
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
            child: PaperMarkdown(
              data: widget.markdown,
              styleSheet: paperReaderMarkdownStyle(),
            ),
          ),
        ),
      ),
    );
  }
}
