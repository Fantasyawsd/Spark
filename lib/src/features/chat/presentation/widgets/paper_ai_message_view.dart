import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/paperflow_markdown.dart';
import '../../domain/chat_message.dart';
import '../paper_ai_ui_tokens.dart';
import 'paper_ai_model_avatar.dart';

class PaperAiMessageView extends StatelessWidget {
  const PaperAiMessageView({
    super.key,
    required this.message,
    required this.streaming,
    required this.searching,
    this.isLatest = false,
    this.onRetry,
    this.onDelete,
    this.onEdit,
    this.onOpenSource,
    this.assistantLabel = '默认助手',
    this.modelName = 'deepseek-v4-flash',
    this.providerName = 'DeepSeek',
  });

  final ChatMessage message;
  final bool streaming;
  final bool searching;
  final bool isLatest;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final Future<bool> Function(Uri uri)? onOpenSource;
  final String assistantLabel;
  final String modelName;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    if (!message.fromUser &&
        message.content.isEmpty &&
        message.reasoningContent.isEmpty &&
        message.sources.isEmpty) {
      return const SizedBox.shrink();
    }

    if (message.fromUser) {
      return _UserMessage(
        message: message,
        onEdit: isLatest ? onEdit : null,
      );
    }

    return _AssistantMessage(
      message: message,
      streaming: streaming,
      onRetry: isLatest ? onRetry : null,
      onDelete: onDelete,
      onOpenSource: onOpenSource,
      assistantLabel: assistantLabel,
      modelName: modelName,
      providerName: providerName,
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message, required this.onEdit});

  final ChatMessage message;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = (viewportWidth * 0.76).clamp(220.0, 420.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(
                  color: PaperAiUiTokens.userBubble,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: PaperMarkdown(
                  data: message.content,
                  styleSheet: paperAiMarkdownStyle(color: PaperFlowColors.ink),
                  selectable: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _MessageActionRow(
            message: message,
            assistant: false,
            onEdit: onEdit,
          ),
        ],
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({
    required this.message,
    required this.streaming,
    required this.onRetry,
    required this.onDelete,
    this.onOpenSource,
    required this.assistantLabel,
    required this.modelName,
    required this.providerName,
  });

  final ChatMessage message;
  final bool streaming;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final Future<bool> Function(Uri uri)? onOpenSource;
  final String assistantLabel;
  final String modelName;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '$assistantLabel / $modelName ($providerName)',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const PaperAiModelAvatar(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          modelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PaperFlowColors.ink,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (message.reasoningContent.isNotEmpty)
            _ReasoningPanel(
              key: const ValueKey('paper-ai-reasoning-panel'),
              reasoning: message.reasoningContent,
              streaming: streaming && message.content.isEmpty,
            ),
          if (message.content.isNotEmpty)
            PaperMarkdown(
              data: message.content,
              styleSheet: paperAiMarkdownStyle(color: PaperFlowColors.ink),
              stabilizeGeneratedSyntax: true,
              selectable: false,
            ),
          if (message.sources.isNotEmpty)
            _SourcesPanel(
              sources: message.sources,
              onOpenSource: onOpenSource,
            ),
          const SizedBox(height: 4),
          _MessageActionRow(
            message: message,
            assistant: true,
            onRetry: onRetry,
            onDelete: onDelete,
          ),
          if (message.status != ChatMessageStatus.complete)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.status == ChatMessageStatus.cancelled
                    ? '已停止生成'
                    : '生成失败',
                style: const TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageActionRow extends StatelessWidget {
  const _MessageActionRow({
    required this.message,
    required this.assistant,
    this.onRetry,
    this.onEdit,
    this.onDelete,
  });

  final ChatMessage message;
  final bool assistant;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MessageActionButton(
            key: ValueKey(
              assistant ? 'paper-ai-assistant-copy' : 'paper-ai-user-copy',
            ),
            tooltip: '复制',
            icon: Icons.copy_all_outlined,
            onPressed: () => _copy(context),
          ),
          if (assistant && onRetry != null)
            _MessageActionButton(
              key: const ValueKey('paper-ai-assistant-retry'),
              tooltip: '重新生成',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          if (!assistant && onEdit != null)
            _MessageActionButton(
              key: const ValueKey('paper-ai-user-edit'),
              tooltip: '修改',
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
          if (assistant)
            _MessageActionButton(
              key: const ValueKey('paper-ai-assistant-more'),
              tooltip: '更多',
              icon: Icons.more_vert_rounded,
              onPressed: () => _showMore(context),
            ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    // COT/reasoning is an internal trace and must never enter the clipboard.
    final text = message.content;
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制消息')),
      );
    }
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PaperAiUiTokens.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('删除消息'),
              onTap: onDelete == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onDelete!();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 20,
        color: onPressed == null
            ? PaperAiUiTokens.actionMuted
            : PaperAiUiTokens.action,
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        maximumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({
    super.key,
    required this.reasoning,
    required this.streaming,
  });

  final String reasoning;
  final bool streaming;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.streaming;
    if (widget.streaming) _startTimer();
  }

  @override
  void didUpdateWidget(covariant _ReasoningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streaming && !oldWidget.streaming) {
      _expanded = true;
      _startTimer();
    } else if (!widget.streaming && oldWidget.streaming) {
      _updateElapsed();
      _stopTimer();
      _expanded = false;
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _elapsed.inMilliseconds > 0
        ? '思考了 ${(_elapsed.inMilliseconds / 1000).toStringAsFixed(1)} 秒'
        : widget.streaming
            ? '正在思考'
            : '思考过程';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PaperAiUiTokens.assistantReasoning,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('paper-ai-reasoning-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: PaperAiUiTokens.reasoning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: widget.streaming
                        ? _ShimmerText(text: title)
                        : Text(
                            title,
                            style: const TextStyle(
                              color: PaperAiUiTokens.assistantReasoningText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: PaperAiUiTokens.assistantReasoningText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
                    child: Container(
                      padding: const EdgeInsets.only(left: 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Color(0x55A9797C),
                            width: 2,
                          ),
                        ),
                      ),
                      child: PaperMarkdown(
                        data: widget.reasoning,
                        styleSheet: paperAiMarkdownStyle(
                          color: PaperAiUiTokens.assistantReasoningText,
                          reasoning: true,
                        ),
                        stabilizeGeneratedSyntax: true,
                        selectable: false,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _startedAt ??= DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _updateElapsed();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateElapsed() {
    final startedAt = _startedAt;
    if (startedAt == null) return;
    setState(() {
      _elapsed = DateTime.now().difference(startedAt);
    });
  }
}

class _ShimmerText extends StatefulWidget {
  const _ShimmerText({required this.text});

  final String text;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.55 + (_controller.value * 0.45),
        child: child,
      ),
      child: Text(
        widget.text,
        style: const TextStyle(
          color: PaperAiUiTokens.assistantReasoningText,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({
    required this.sources,
    this.onOpenSource,
  });

  final List<ChatSource> sources;
  final Future<bool> Function(Uri uri)? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final visibleSources = sources.take(4).toList(growable: false);
    final remaining = sources.length - visibleSources.length;
    return Container(
      key: const ValueKey('paper-ai-sources'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: PaperAiUiTokens.assistantReasoning.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.link_rounded,
                size: 17,
                color: PaperFlowColors.muted,
              ),
              const SizedBox(width: 7),
              const Text(
                '来源',
                style: TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${sources.length} 个',
                style: const TextStyle(
                  color: PaperFlowColors.subtle,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < visibleSources.length; index++)
            _SourceRow(
              index: index + 1,
              source: visibleSources[index],
              onOpenSource: onOpenSource,
            ),
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
    final uri = _validUri(source.url);
    return Semantics(
      button: uri != null,
      label: uri == null ? source.title : '打开来源 ${source.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('paper-ai-source-$index'),
          onTap: uri == null ? null : () => _open(context, uri),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 7, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 21,
                  height: 21,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PaperAiUiTokens.canvas,
                    borderRadius: BorderRadius.circular(7),
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
                        style: TextStyle(
                          color: uri == null
                              ? PaperFlowColors.ink
                              : PaperFlowColors.blue,
                          fontSize: 11.5,
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
                if (uri != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 6, top: 2),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: PaperFlowColors.subtle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final opened = await (onOpenSource?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && context.mounted) {
        _showOpenFailure(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showOpenFailure(context);
      }
    }
  }

  void _showOpenFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开来源链接')),
    );
  }

  static Uri? _validUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  static String _host(String url) {
    return Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
  }
}
