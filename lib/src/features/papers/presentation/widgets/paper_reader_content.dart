import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../domain/paper.dart';

class PaperReaderKeywordContent extends StatelessWidget {
  const PaperReaderKeywordContent({
    super.key,
    required this.keywords,
    required this.loadingCache,
    required this.generating,
    required this.error,
    required this.onGenerate,
    required this.onRefresh,
    required this.onCancel,
  });

  final List<String> keywords;
  final bool loadingCache;
  final bool generating;
  final String? error;
  final VoidCallback onGenerate;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (loadingCache && keywords.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (keywords.isEmpty) {
      return PaperReaderEmptyState(
        icon: Icons.key_rounded,
        title: generating ? '正在生成关键词…' : '尚未生成关键词',
        message: error ?? '关键词将从论文标题和 Abstract 中提取。',
        actionLabel: generating
            ? '停止'
            : error == null
                ? '生成'
                : '重试',
        onAction: generating ? onCancel : onGenerate,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('paper-keyword-refresh'),
            onPressed: generating ? onCancel : onRefresh,
            child: Text(generating ? '停止' : '重新生成'),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: SparkDesignTokens.space2),
            child: Text(
              error!,
              style: TextStyle(
                color: SparkColors.of(context).danger,
                fontSize: SparkFontSizes.footnote,
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final keyword in keywords) Chip(label: Text(keyword)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PaperReaderAuthorContent extends StatelessWidget {
  const PaperReaderAuthorContent({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: paper.authors.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline_rounded),
        title: Text(paper.authors[index]),
      ),
    );
  }
}

class PaperReaderAiInterpretationContent extends StatelessWidget {
  const PaperReaderAiInterpretationContent({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return PaperReaderEmptyState(
      icon: Icons.auto_awesome_rounded,
      title: '围绕当前论文提问',
      message: '当前对话基于论文元数据和摘要，不包含 PDF 全文。',
      actionLabel: '打开 ChatPaper',
      onAction: onOpen,
    );
  }
}

class PaperReaderEmptyState extends StatelessWidget {
  const PaperReaderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SparkDesignTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: SparkColors.of(context).muted, size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SparkColors.of(context).muted,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class PaperReaderAiInterpretButton extends StatelessWidget {
  const PaperReaderAiInterpretButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('paper-ai-entry'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: SparkColors.of(context).primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(
          horizontal: SparkDesignTokens.space3,
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: const Text(
        'AI 解读',
        style: TextStyle(
          fontSize: SparkFontSizes.footnote,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class MobileSelectableText extends StatelessWidget {
  const MobileSelectableText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.onTap,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    if (mobile) {
      return SelectableText(
        text,
        maxLines: maxLines,
        style: style,
        onTap: onTap,
      );
    }
    final child = Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
