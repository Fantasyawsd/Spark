import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/widgets/spark_markdown.dart';
import '../paper_ai_ui_tokens.dart';

class PaperAiReasoningPanel extends StatefulWidget {
  const PaperAiReasoningPanel({
    super.key,
    required this.reasoning,
    required this.streaming,
  });

  final String reasoning;
  final bool streaming;

  @override
  State<PaperAiReasoningPanel> createState() => _PaperAiReasoningPanelState();
}

class _PaperAiReasoningPanelState extends State<PaperAiReasoningPanel> {
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
  void didUpdateWidget(covariant PaperAiReasoningPanel oldWidget) {
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
    return Container(
      key: const ValueKey('paper-ai-reasoning-surface'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PaperAiUiTokens.assistantReasoning(context),
        borderRadius: BorderRadius.circular(SparkDesignTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          _buildReasoning(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = _elapsed.inMilliseconds > 0
        ? '思考了 ${(_elapsed.inMilliseconds / 1000).toStringAsFixed(1)} 秒'
        : widget.streaming
            ? '正在思考'
            : '思考过程';
    return InkWell(
      key: const ValueKey('paper-ai-reasoning-toggle'),
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(SparkDesignTokens.radiusXl),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 18,
              color: PaperAiUiTokens.accent(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: widget.streaming
                  ? _ShimmerText(text: title)
                  : Text(
                      title,
                      style: TextStyle(
                        color: PaperAiUiTokens.assistantReasoningText(context),
                        fontSize: SparkFontSizes.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: PaperAiUiTokens.assistantReasoningText(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasoning(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: _expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
              child: Container(
                padding: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: PaperAiUiTokens.composerBorder(context),
                      width: 2,
                    ),
                  ),
                ),
                child: SparkMarkdown(
                  data: widget.reasoning,
                  styleSheet: sparkMarkdownStyle(
                    context,
                    color: PaperAiUiTokens.assistantReasoningText(context),
                    reasoning: true,
                  ),
                  stabilizeGeneratedSyntax: true,
                  selectable: false,
                ),
              ),
            )
          : const SizedBox.shrink(),
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
        style: TextStyle(
          color: PaperAiUiTokens.assistantReasoningText(context),
          fontSize: SparkFontSizes.bodyLarge,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
