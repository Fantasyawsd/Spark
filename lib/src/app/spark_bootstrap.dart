import 'package:flutter/material.dart';

import '../core/motion/motion_tokens.dart';
import '../core/theme/spark_theme.dart';

/// Displays the application shell immediately and temporarily covers it with
/// the startup animation when requested.
class SparkBootstrap extends StatefulWidget {
  const SparkBootstrap({
    required this.showSplash,
    required this.child,
    super.key,
  });

  final bool showSplash;
  final Widget child;

  @override
  State<SparkBootstrap> createState() => _SparkBootstrapState();
}

class _SparkBootstrapState extends State<SparkBootstrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late bool _splashComplete;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _splashComplete = !widget.showSplash;
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.splashDuration,
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 42),
      TweenSequenceItem<double>(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 58,
      ),
    ]).animate(_controller);
    _scale = Tween(
      begin: 1.0,
      end: 1.035,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.showSplash) {
      _controller.addStatusListener(_handleAnimationStatus);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.showSplash || _animationStarted || _splashComplete) return;

    _animationStarted = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _controller.value = 1;
      _splashComplete = true;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_splashComplete)
          AbsorbPointer(
            child: FadeTransition(
              opacity: _opacity,
              child: ColoredBox(
                key: const ValueKey('spark-splash'),
                color: SparkColors.of(context).canvas,
                child: Center(
                  child: ScaleTransition(
                    scale: _scale,
                    child: Image.asset(
                      'assets/images/spark_logo.png',
                      width: 240,
                      height: 240,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _splashComplete = true);
    }
  }
}
