import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/widgets/spark_markdown.dart';
import '../../domain/chat_message.dart';
import '../paper_ai_ui_tokens.dart';
import 'paper_ai_message_actions.dart';
import 'paper_ai_model_avatar.dart';
import 'paper_ai_reasoning_panel.dart';
import 'paper_ai_sources_panel.dart';

class PaperAiUserMessage extends StatelessWidget {
  const PaperAiUserMessage({
    super.key,
    required this.message,
    required this.onEdit,
    required this.selectionMode,
  });

  final ChatMessage message;
  final VoidCallback? onEdit;
  final bool selectionMode;

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
                key: const ValueKey('paper-ai-user-bubble'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(
                  color: PaperAiUiTokens.userBubble(context),
                  borderRadius:
                      BorderRadius.circular(SparkDesignTokens.radius2Xl),
                ),
                child: SparkMarkdown(
                  data: message.content,
                  styleSheet: sparkMarkdownStyle(
                    context,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  selectable: false,
                ),
              ),
            ),
          ),
          if (!selectionMode) ...[
            const SizedBox(height: 4),
            PaperAiMessageActionRow(
              message: message,
              assistant: false,
              onEdit: onEdit,
            ),
          ],
        ],
      ),
    );
  }
}

class PaperAiAssistantMessage extends StatelessWidget {
  const PaperAiAssistantMessage({
    super.key,
    required this.message,
    required this.streaming,
    required this.onRetry,
    required this.onDelete,
    this.onOpenSource,
    required this.selectionMode,
    required this.assistantLabel,
    required this.modelName,
    required this.providerName,
  });

  final ChatMessage message;
  final bool streaming;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final Future<bool> Function(Uri uri)? onOpenSource;
  final bool selectionMode;
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
          _buildIdentity(context),
          const SizedBox(height: 8),
          if (message.reasoningContent.isNotEmpty)
            IgnorePointer(
              ignoring: selectionMode,
              child: PaperAiReasoningPanel(
                key: const ValueKey('paper-ai-reasoning-panel'),
                reasoning: message.reasoningContent,
                streaming: streaming && message.content.isEmpty,
              ),
            ),
          if (message.content.isNotEmpty) _buildContent(context),
          if (message.sources.isNotEmpty)
            IgnorePointer(
              ignoring: selectionMode,
              child: PaperAiSourcesPanel(
                sources: message.sources,
                onOpenSource: onOpenSource,
              ),
            ),
          if (!selectionMode) ...[
            const SizedBox(height: 4),
            PaperAiMessageActionRow(
              message: message,
              assistant: true,
              onRetry: onRetry,
              onDelete: onDelete,
            ),
          ],
          if (!selectionMode && message.status != ChatMessageStatus.complete)
            _buildStatus(context),
        ],
      ),
    );
  }

  Widget _buildIdentity(BuildContext context) {
    return Semantics(
      label: '$assistantLabel / $modelName ($providerName)',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const PaperAiModelAvatar(size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              modelName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: SparkFontSizes.titleSmall,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SparkMarkdown(
      data: message.content,
      styleSheet: sparkMarkdownStyle(
        context,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      stabilizeGeneratedSyntax: true,
      selectable: false,
    );
  }

  Widget _buildStatus(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message.status == ChatMessageStatus.cancelled ? '已停止生成' : '生成失败',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: SparkFontSizes.caption,
        ),
      ),
    );
  }
}

class PaperAiSelectableMessage extends StatelessWidget {
  const PaperAiSelectableMessage({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: selected ? '已选择消息' : '选择消息',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        decoration: BoxDecoration(
          color: selected
              ? PaperAiUiTokens.assistantReasoning(
                  context,
                ).withValues(alpha: 0.55)
              : Colors.transparent,
          border: Border.all(
            color:
                selected ? PaperAiUiTokens.accent(context) : Colors.transparent,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(SparkDesignTokens.radius2Xl),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
          child: Stack(
            children: [
              child,
              Positioned(
                top: 4,
                left: 2,
                child: _SelectionIndicator(selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? PaperAiUiTokens.accent(context)
            : Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? PaperAiUiTokens.accent(context)
              : PaperAiUiTokens.actionMuted(context),
          width: 1.4,
        ),
      ),
      child: SizedBox(
        width: 22,
        height: 22,
        child: selected
            ? Icon(
                Icons.check_rounded,
                size: 15,
                color: Theme.of(context).colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }
}
