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
    final palette = SparkColors.of(context);
    // 品牌化启动屏：canvas 向强调色 5% 染色过渡的渐变底；
    // logo 尺寸随窗口收缩，避免小窗口溢出。
    final splashSize = MediaQuery.sizeOf(context);
    final logoSize = (splashSize.width * 0.62).clamp(160.0, 240.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_splashComplete)
          AbsorbPointer(
            child: FadeTransition(
              opacity: _opacity,
              child: DecoratedBox(
                key: const ValueKey('spark-splash'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.canvas,
                      Color.alphaBlend(
                        palette.primary.withValues(alpha: 0.05),
                        palette.canvas,
                      ),
                    ],
                  ),
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: _scale,
                    child: Image.asset(
                      'assets/images/spark_logo.png',
                      width: logoSize,
                      height: logoSize,
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
