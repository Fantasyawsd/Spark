import 'package:flutter/material.dart';

import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';

class PaperEmptyState extends StatelessWidget {
  const PaperEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.topInset,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final double topInset;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('paper-empty-state'),
      padding: EdgeInsets.fromLTRB(28, topInset, 28, 110),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              color: SparkColors.of(context).muted,
              size: 38,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: SparkColors.of(context).ink,
                fontSize: SparkFontSizes.title,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SparkColors.of(context).muted,
                fontSize: SparkFontSizes.footnote,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
