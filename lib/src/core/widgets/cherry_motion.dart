import 'package:flutter/material.dart';

import '../motion/motion_tokens.dart';

/// Short, directional content reveal used by Cherry Studio for transient UI.
class CherryEntryAnimation extends StatefulWidget {
  const CherryEntryAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.035),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<CherryEntryAnimation> createState() => _CherryEntryAnimationState();
}

class _CherryEntryAnimationState extends State<CherryEntryAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.entryDuration,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: MotionTokens.enterCurve,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curve);
    _scale = Tween<double>(begin: 0.985, end: 1).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _controller.value = 1;
      return;
    }
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }

  Future<void> _start() async {
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) return;
    }
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _controller.value = 1;
      return;
    }
    await _controller.forward();
  }
}
