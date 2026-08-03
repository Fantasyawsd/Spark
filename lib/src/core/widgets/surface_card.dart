import 'package:flutter/material.dart';

import 'cherry_primitives.dart';
import '../theme/paperflow_design_tokens.dart';
import '../theme/paperflow_theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PaperFlowDesignTokens.space4),
    this.margin,
    this.radius = PaperFlowDesignTokens.radiusLg,
    this.color = PaperFlowColors.card,
    this.border,
    this.level = CherrySurfaceLevel.flat,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color color;
  final Border? border;
  final CherrySurfaceLevel level;

  @override
  Widget build(BuildContext context) {
    return CherrySurface(
      margin: margin,
      padding: padding,
      color: color,
      radius: radius,
      border: border,
      level: level,
      child: child,
    );
  }
}
