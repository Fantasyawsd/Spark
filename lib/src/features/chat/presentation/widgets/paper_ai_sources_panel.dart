import 'package:flutter/material.dart';

import '../../../../core/platform/external_http_uri.dart';
import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../domain/chat_message.dart';
import '../paper_ai_ui_tokens.dart';

class PaperAiSourcesPanel extends StatefulWidget {
  const PaperAiSourcesPanel({
    super.key,
    required this.sources,
    this.onOpenSource,
  });

  final List<ChatSource> sources;
  final Future<bool> Function(Uri uri)? onOpenSource;

  @override
  State<PaperAiSourcesPanel> createState() => _PaperAiSourcesPanelState();
}

class _PaperAiSourcesPanelState extends State<PaperAiSourcesPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('paper-ai-sources'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: PaperAiUiTokens.assistantReasoning(
          context,
        ).withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(SparkDesignTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildSourceList(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      key: const ValueKey('paper-ai-sources-toggle'),
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              Icons.link_rounded,
              size: 17,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Text(
              '来源',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: SparkFontSizes.footnote,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.sources.length} 个',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: SparkFontSizes.caption,
              ),
            ),
            const Spacer(),
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 19,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceList(BuildContext context) {
    final visibleSources = widget.sources.take(4).toList(growable: false);
    final remaining = widget.sources.length - visibleSources.length;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 7),
                for (var index = 0; index < visibleSources.length; index++)
                  _SourceRow(
                    index: index + 1,
                    source: visibleSources[index],
                    onOpenSource: widget.onOpenSource,
                  ),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 28, top: 2),
                    child: Text(
                      '另有 $remaining 个来源',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: SparkFontSizes.caption,
                      ),
                    ),
                  ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.index,
    required this.source,
    this.onOpenSource,
  });

  final int index;
  final ChatSource source;
  final Future<bool> Function(Uri uri)? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final uri = validExternalHttpUri(source.url);
    final canOpen = uri != null && onOpenSource != null;
    return Semantics(
      button: canOpen,
      label: canOpen ? '打开来源 ${source.title}' : source.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('paper-ai-source-$index'),
          onTap: canOpen ? () => _open(context, uri) : null,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 7, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SourceIndex(index: index),
                const SizedBox(width: 8),
                Expanded(
                  child: _SourceDetails(
                    source: source,
                    canOpen: canOpen,
                  ),
                ),
                if (canOpen) const _OpenSourceIcon(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final opener = onOpenSource;
    if (opener == null) return;
    try {
      if (!await opener(uri) && context.mounted) {
        _showOpenFailure(context);
      }
    } catch (_) {
      if (context.mounted) _showOpenFailure(context);
    }
  }

  void _showOpenFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开来源链接')),
    );
  }
}

class _SourceIndex extends StatelessWidget {
  const _SourceIndex({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PaperAiUiTokens.canvas(context),
        borderRadius: BorderRadius.circular(SparkDesignTokens.radiusSm),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: SparkFontSizes.tiny,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SourceDetails extends StatelessWidget {
  const _SourceDetails({required this.source, required this.canOpen});

  final ChatSource source;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          source.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: canOpen
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.onSurface,
            fontSize: SparkFontSizes.caption,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          _host(source.url),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: SparkFontSizes.tiny,
          ),
        ),
      ],
    );
  }

  static String _host(String url) {
    return Uri.tryParse(url.trim())?.host.replaceFirst('www.', '') ?? url;
  }
}

class _OpenSourceIcon extends StatelessWidget {
  const _OpenSourceIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 2),
      child: Icon(
        Icons.open_in_new_rounded,
        size: 15,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
