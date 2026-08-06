import 'package:flutter/material.dart';

import '../motion/motion_tokens.dart';
import '../theme/spark_design_tokens.dart';
import '../theme/spark_theme.dart';

enum CherryButtonVariant { primary, outline, secondary, ghost, destructive }

enum CherryButtonSize { small, medium, large }

/// Compact action primitive mapped from Cherry Studio's Button variants.
class CherryButton extends StatelessWidget {
  const CherryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.leading,
    this.trailing,
    this.variant = CherryButtonVariant.primary,
    this.size = CherryButtonSize.medium,
    this.loading = false,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final CherryButtonVariant variant;
  final CherryButtonSize size;
  final bool loading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final colors = _colors;
    final heights = switch (size) {
      CherryButtonSize.small => (height: 28.0, horizontal: 10.0),
      CherryButtonSize.medium => (height: 32.0, horizontal: 12.0),
      CherryButtonSize.large => (height: 38.0, horizontal: 16.0),
    };
    final textStyle = switch (size) {
      CherryButtonSize.small => const TextStyle(fontSize: 12),
      CherryButtonSize.medium => const TextStyle(fontSize: 13),
      CherryButtonSize.large => const TextStyle(fontSize: 14),
    };
    final button = Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: colors.background,
        borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
          splashFactory: InkRipple.splashFactory,
          child: AnimatedContainer(
            duration: MotionTokens.duration(
              context,
              MotionTokens.feedbackDuration,
            ),
            constraints: BoxConstraints(minHeight: heights.height),
            padding: EdgeInsets.symmetric(horizontal: heights.horizontal),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                SparkDesignTokens.radiusMd,
              ),
              border: Border.all(
                color: colors.border,
                width: SparkDesignTokens.borderWidth,
              ),
              boxShadow: variant == CherryButtonVariant.primary ||
                      variant == CherryButtonVariant.destructive
                  ? SparkDesignTokens.interactiveShadow
                  : null,
            ),
            child: DefaultTextStyle(
              style: textStyle.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: colors.foreground,
                      ),
                    )
                  else if (leading != null)
                    leading!,
                  if (loading || leading != null) const SizedBox(width: 6),
                  child,
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child:
          tooltip == null ? button : Tooltip(message: tooltip!, child: button),
    );
  }

  _CherryButtonColors get _colors {
    switch (variant) {
      case CherryButtonVariant.primary:
        return _CherryButtonColors(
          background: SparkColors.primary,
          foreground: Colors.white,
          border: SparkColors.primary,
        );
      case CherryButtonVariant.outline:
        return const _CherryButtonColors(
          background: Colors.transparent,
          foreground: SparkColors.ink,
          border: SparkColors.line,
        );
      case CherryButtonVariant.secondary:
        return const _CherryButtonColors(
          background: SparkColors.surfaceMuted,
          foreground: SparkColors.ink,
          border: Colors.transparent,
        );
      case CherryButtonVariant.ghost:
        return const _CherryButtonColors(
          background: Colors.transparent,
          foreground: SparkColors.ink,
          border: Colors.transparent,
        );
      case CherryButtonVariant.destructive:
        return const _CherryButtonColors(
          background: SparkColors.danger,
          foreground: Colors.white,
          border: SparkColors.danger,
        );
    }
  }
}

class _CherryButtonColors {
  const _CherryButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

class CherryIconButton extends StatelessWidget {
  const CherryIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.badge,
    this.iconSize = 18,
    this.size = 32,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final Widget? badge;
  final double iconSize;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = selected ? SparkColors.accent : Colors.transparent;
    final foreground =
        selected ? SparkColors.accentForeground : SparkColors.muted;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
            hoverColor: SparkColors.accent,
            focusColor: SparkColors.accent,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: badge ?? Icon(icon, size: iconSize, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum CherrySurfaceLevel { flat, interactive, floating }

class CherrySurface extends StatelessWidget {
  const CherrySurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SparkDesignTokens.space4),
    this.margin,
    this.color = SparkColors.card,
    this.level = CherrySurfaceLevel.flat,
    this.radius = SparkDesignTokens.radiusLg,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final CherrySurfaceLevel level;
  final double radius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final shadow = switch (level) {
      CherrySurfaceLevel.flat => null,
      CherrySurfaceLevel.interactive => SparkDesignTokens.interactiveShadow,
      CherrySurfaceLevel.floating => SparkDesignTokens.floatingShadow,
    };
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: SparkColors.line),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}
