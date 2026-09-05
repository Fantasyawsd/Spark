import 'package:flutter/material.dart';

import '../theme/spark_design_tokens.dart';
import '../theme/spark_theme.dart';

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
    final background =
        selected ? SparkColors.of(context).accent : Colors.transparent;
    final foreground = selected
        ? SparkColors.of(context).accentForeground
        : SparkColors.of(context).muted;
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
            hoverColor: SparkColors.of(context).accent,
            focusColor: SparkColors.of(context).accent,
            // 视觉尺寸保持 size，命中区外扩到 44px 触控标准。
            child: SizedBox(
              width: size < 44 ? 44 : size,
              height: size < 44 ? 44 : size,
              child: Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child:
                        badge ?? Icon(icon, size: iconSize, color: foreground),
                  ),
                ),
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
    this.color,
    this.level = CherrySurfaceLevel.flat,
    this.radius = SparkDesignTokens.radiusLg,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final CherrySurfaceLevel level;
  final double radius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final shadow = switch (level) {
      CherrySurfaceLevel.flat => null,
      CherrySurfaceLevel.interactive =>
        SparkDesignTokens.interactiveShadowFor(brightness),
      CherrySurfaceLevel.floating =>
        SparkDesignTokens.floatingShadowFor(brightness),
    };
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? SparkColors.of(context).card,
        borderRadius: BorderRadius.circular(radius),
        // iOS 式分层：默认无边框，靠 canvas 与 card 底色差形成层次；
        // 显式传入的 border（如引用块、分段控件）仍然生效。
        border: border,
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}
