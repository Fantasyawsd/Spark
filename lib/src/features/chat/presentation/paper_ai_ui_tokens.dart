import 'package:flutter/material.dart';

/// Chat-specific semantic colors derived from the active application theme.
abstract final class PaperAiUiTokens {
  static Color canvas(BuildContext context) => _accentBlend(context, 0.02);

  static Color composer(BuildContext context) => _accentBlend(context, 0.06);

  static Color composerBorder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.18),
      scheme.outlineVariant,
    );
  }

  static Color userBubble(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer;

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
