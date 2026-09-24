import 'package:flutter/material.dart';

import '../../../core/theme/spark_theme.dart';

/// Chat-specific semantic colors derived from the active application theme.
abstract final class PaperAiUiTokens {
  static Color canvas(BuildContext context) => SparkColors.of(context).canvas;

  static Color sideChatCanvas(BuildContext context) =>
      _accentBlend(context, 0.10);

  static Color composer(BuildContext context) => SparkColors.of(context).card;

  static Color composerBorder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.18),
      scheme.outlineVariant,
    );
  }

  static Color userBubble(BuildContext context) =>
      SparkColors.of(context).surfaceMuted;

  static Color assistantReasoning(BuildContext context) =>
      _accentBlend(context, 0.08);

  static Color assistantReasoningText(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimaryContainer;

  static Color accent(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color action(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color actionMuted(BuildContext context) =>
      Theme.of(context).colorScheme.outline;

  static Color shadow(BuildContext context) =>
      Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05);

  static Color disabledControl(BuildContext context) =>
      _accentBlend(context, 0.08);

  static Color errorSurface(BuildContext context) =>
      Theme.of(context).colorScheme.errorContainer;

  static Color _accentBlend(BuildContext context, double opacity) {
    final scheme = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      scheme.primary.withValues(alpha: opacity),
      scheme.surface,
    );
  }
}
