import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';

class PaperEntryAnimation extends StatelessWidget {
  const PaperEntryAnimation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MotionTokens.duration(
      context,
      MotionTokens.pageDuration,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: MotionTokens.enterCurve,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
