import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/paperflow_markdown.dart';
import '../../domain/chat_message.dart';
import '../paper_ai_ui_tokens.dart';

class PaperAiMessageView extends StatelessWidget {
  const PaperAiMessageView({
    super.key,
    required this.message,
    required this.streaming,
    required this.searching,
    this.onRetry,
    this.assistantLabel = '默认助手',
    this.modelName = 'deepseek-v4-flash',
    this.providerName = 'DeepSeek',
  });

  final ChatMessage message;
  final bool streaming;
  final bool searching;
  final VoidCallback? onRetry;
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
        onRetry: onRetry,
      );
    }

    return _AssistantMessage(
      message: message,
      streaming: streaming,
      searching: searching,
      onRetry: onRetry,
      assistantLabel: assistantLabel,
      modelName: modelName,
      providerName: providerName,
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message, required this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = (viewportWidth * 0.76).clamp(220.0, 420.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(left: 46, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _UserHeader(),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: PaperAiUiTokens.userBubble,
                  borderRadius: BorderRadius.circular(22),
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
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '用户',
          style: TextStyle(
            color: PaperFlowColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF8EDB54), Color(0xFF46B8D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({
    required this.message,
    required this.streaming,
    required this.searching,
    required this.onRetry,
    required this.assistantLabel,
    required this.modelName,
    required this.providerName,
  });

  final ChatMessage message;
  final bool streaming;
  final bool searching;
  final VoidCallback? onRetry;
  final String assistantLabel;
  final String modelName;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '$assistantLabel / $modelName ($providerName)',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _AssistantAvatar(size: 40),
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
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (searching || streaming)
                        _StatusPill(
                          label: searching ? '正在搜索' : '正在生成',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
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
            _SourcesPanel(sources: message.sources),
          const SizedBox(height: 6),
          _MessageActionRow(
            message: message,
            assistant: true,
            onRetry: onRetry,
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

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF4C83F5), Color(0xFFBFD8FF)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        boxShadow: [
          BoxShadow(
            color: PaperAiUiTokens.modelBlue.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: size * 0.48,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PaperAiUiTokens.assistantReasoning,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PaperAiUiTokens.assistantReasoningText,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageActionRow extends StatelessWidget {
  const _MessageActionRow({
    required this.message,
    required this.assistant,
    required this.onRetry,
  });

  final ChatMessage message;
  final bool assistant;
  final VoidCallback? onRetry;

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
          _MessageActionButton(
            key: ValueKey(
              assistant ? 'paper-ai-assistant-retry' : 'paper-ai-user-retry',
            ),
            tooltip: '重新生成',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
          if (assistant)
            _MessageActionButton(
              tooltip: '朗读',
              icon: Icons.volume_up_outlined,
              onPressed: () => _showMessageHint(context, '朗读功能即将接入。'),
            ),
          if (assistant)
            _MessageActionButton(
              tooltip: '翻译',
              icon: Icons.translate_rounded,
              onPressed: () => _showMessageHint(context, '翻译功能即将接入。'),
            ),
          _MessageActionButton(
            key: ValueKey(
              assistant ? 'paper-ai-assistant-more' : 'paper-ai-user-more',
            ),
            tooltip: '更多',
            icon: Icons.more_vert_rounded,
            onPressed: () => _showMore(context),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final text = [message.reasoningContent, message.content]
        .where((part) => part.trim().isNotEmpty)
        .join('\n\n');
    if (text.isEmpty) return;
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
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('复制消息'),
              onTap: () async {
                Navigator.pop(context);
                await _copy(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('查看消息详情'),
              onTap: () {
                Navigator.pop(context);
                _showMessageHint(context, '当前消息由 $modelLabel 生成。');
              },
            ),
          ],
        ),
      ),
    );
  }

  String get modelLabel => assistant ? 'Assistant' : '用户';

  void _showMessageHint(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
        size: 23,
        color: onPressed == null
            ? PaperAiUiTokens.actionMuted
            : PaperAiUiTokens.action,
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size(34, 34),
        maximumSize: const Size(34, 34),
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('paper-ai-reasoning-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: PaperAiUiTokens.reasoning,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: widget.streaming
                        ? _ShimmerText(text: title)
                        : Text(
                            title,
                            style: const TextStyle(
                              color: PaperAiUiTokens.assistantReasoningText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: PaperAiUiTokens.assistantReasoningText,
                    size: 23,
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
                    padding: const EdgeInsets.fromLTRB(17, 0, 17, 15),
                    child: Container(
                      padding: const EdgeInsets.only(left: 20),
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
  const _SourcesPanel({required this.sources});

  final List<ChatSource> sources;

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
  final ChatSource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
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
                  style: const TextStyle(
                    color: PaperFlowColors.ink,
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
        ],
      ),
    );
  }

  static String _host(String url) {
    return Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
  }
}
