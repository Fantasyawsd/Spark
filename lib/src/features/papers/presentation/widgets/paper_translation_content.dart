import 'package:flutter/material.dart';

import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import 'paper_tab_body.dart';

class PaperTranslationContent extends StatelessWidget {
  const PaperTranslationContent({
    super.key,
    required this.markdown,
    required this.loadingCache,
    required this.translating,
    required this.error,
    required this.onRetry,
    required this.onRefresh,
    required this.onCancel,
    required this.onExpand,
  });

  final String markdown;
  final bool loadingCache;
  final bool translating;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    if (loadingCache && markdown.isEmpty) {
      return const _TranslationStatus(
        icon: CircularProgressIndicator(strokeWidth: 2),
        title: '正在读取摘要…',
      );
    }
    if (translating && markdown.isEmpty) {
      return _TranslationStatus(
        icon: const CircularProgressIndicator(strokeWidth: 2),
        title: '正在生成…',
        actionLabel: '停止',
        onAction: onCancel,
      );
    }
    if (error != null && markdown.isEmpty) {
      return _TranslationStatus(
        icon: Icon(
          Icons.error_outline_rounded,
          color: SparkColors.danger,
        ),
        title: '生成失败，点击重试',
        actionLabel: '重试',
        onAction: onRetry,
      );
    }
    if (markdown.isEmpty) {
      return _TranslationStatus(
        icon: Icon(
          Icons.translate_rounded,
          color: SparkColors.primary,
        ),
        title: '生成中文摘要',
        actionLabel: '生成',
        onAction: onRetry,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 30,
          child: Row(
            children: [
              if (translating) ...[
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
                const SizedBox(width: 7),
                const Text(
                  '正在生成…',
                  style: TextStyle(
                    color: SparkColors.muted,
                    fontSize: SparkFontSizes.caption,
                  ),
                ),
              ],
              const Spacer(),
              TextButton(
                key: const ValueKey('paper-translation-refresh'),
                onPressed: translating ? onCancel : onRefresh,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(translating ? '停止' : '重新翻译'),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              error!,
              style: const TextStyle(
                  color: SparkColors.danger, fontSize: SparkFontSizes.caption),
            ),
          ),
        Expanded(
          child: PaperTabBody(
            text: markdown,
            expandable: true,
            stabilizeGeneratedSyntax: true,
            onExpand: onExpand,
          ),
        ),
      ],
    );
  }
}

class _TranslationStatus extends StatelessWidget {
  const _TranslationStatus({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final Widget icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 24, height: 24, child: icon),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SparkColors.muted,
                fontSize: SparkFontSizes.bodySmall,
                height: 1.4,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
