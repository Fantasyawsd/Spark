import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../application/paper_ai_service.dart';
import 'paper_markdown.dart';

class PaperAiMessageView extends StatelessWidget {
  const PaperAiMessageView({
    super.key,
    required this.message,
    required this.streaming,
    required this.searching,
  });

  final PaperAiMessage message;
  final bool streaming;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    if (!message.fromUser &&
        message.content.isEmpty &&
        message.reasoningContent.isEmpty &&
        message.sources.isEmpty) {
      return const SizedBox.shrink();
    }
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final maxUserWidth = (viewportWidth * 0.76).clamp(220.0, 460.0).toDouble();

    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxUserWidth),
          margin: const EdgeInsets.only(left: 46, bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: PaperFlowColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: PaperMarkdown(
            data: message.content,
            styleSheet: paperAiMarkdownStyle(color: Colors.white),
          ),
        ),
      );
    }

    final status = _assistantStatus;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 17),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: PaperFlowColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: PaperFlowColors.primary,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'DeepSeek',
                style: TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                _AssistantStatus(label: status),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (message.reasoningContent.isNotEmpty)
            _ReasoningPanel(
              reasoning: message.reasoningContent,
              streaming: streaming && message.content.isEmpty,
            ),
          if (message.content.isNotEmpty)
            PaperMarkdown(
              data: message.content,
              styleSheet: paperAiMarkdownStyle(color: PaperFlowColors.ink),
              stabilizeGeneratedSyntax: true,
            ),
          if (message.sources.isNotEmpty)
            _SourcesPanel(sources: message.sources),
        ],
      ),
    );
  }

  String? get _assistantStatus {
    if (searching) return '正在搜索';
    if (streaming && message.content.isNotEmpty) return '正在生成';
    if (message.reasoningContent.isNotEmpty) return '思考完成';
    return null;
  }
}

class _AssistantStatus extends StatelessWidget {
  const _AssistantStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: PaperFlowColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: PaperFlowColors.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({required this.sources});

  final List<PaperAiSource> sources;

  @override
  Widget build(BuildContext context) {
    final visibleSources = sources.take(4).toList(growable: false);
    final remaining = sources.length - visibleSources.length;
    return Container(
      key: const ValueKey('paper-ai-sources'),
      margin: const EdgeInsets.only(top: 13),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.link_rounded,
                size: 15,
                color: PaperFlowColors.muted,
              ),
              const SizedBox(width: 6),
              const Text(
                '来源',
                style: TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${sources.length} 个',
                style: const TextStyle(
                  color: PaperFlowColors.subtle,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < visibleSources.length; index++)
            _SourceRow(index: index + 1, source: visibleSources[index]),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text(
                '另有 $remaining 个来源',
                style: const TextStyle(
                  color: PaperFlowColors.subtle,
                  fontSize: 10.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.index, required this.source});

  final int index;
  final PaperAiSource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PaperFlowColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _host(source.url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PaperFlowColors.subtle,
                    fontSize: 9.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _host(String url) {
    return Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
  }
}

class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({required this.reasoning, required this.streaming});

  final String reasoning;
  final bool streaming;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  late bool _expanded = widget.streaming;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('paper-ai-reasoning-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  if (widget.streaming)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 1.7),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 7),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: PaperFlowColors.muted,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      widget.streaming ? '正在思考' : '思考过程',
                      style: const TextStyle(
                        color: PaperFlowColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!widget.streaming && !_expanded)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Text(
                        '点击展开',
                        style: TextStyle(
                          color: PaperFlowColors.subtle,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: PaperFlowColors.subtle,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: PaperMarkdown(
                      data: widget.reasoning,
                      styleSheet: paperAiMarkdownStyle(
                        color: PaperFlowColors.muted,
                        reasoning: true,
                      ),
                      stabilizeGeneratedSyntax: true,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
