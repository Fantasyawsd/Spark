import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PaperAiAndroidChatBottomBarFollower extends StatelessWidget {
  const PaperAiAndroidChatBottomBarFollower({
    super.key,
    required this.scrollController,
    required this.child,
  });

  final PaperAiImeAnchoringScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return child;

    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    scrollController.updateImeInset(keyboardInset);
    // 只平移体积很小的底部栏；消息视口不参与 IME 合成变换。
    return Transform.translate(
      offset: Offset(0, -keyboardInset),
      child: MediaQuery(
        data: mediaQuery.removeViewInsets(removeBottom: true),
        child: RepaintBoundary(child: child),
      ),
    );
  }
}

class PaperAiAndroidImeScrollSpacer extends StatelessWidget {
  const PaperAiAndroidImeScrollSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return SizedBox(height: MediaQuery.viewInsetsOf(context).bottom);
  }
}

class PaperAiImeAnchoringScrollController extends ScrollController {
  static const double _followThreshold = 160;

  double _imeInset = 0;

  void updateImeInset(double nextInset) {
    if (nextInset == _imeInset) return;
    final delta = nextInset - _imeInset;
    _imeInset = nextInset;
    for (final position in positions.whereType<_ImeAnchoringScrollPosition>()) {
      position.queueImeCorrection(delta, _followThreshold);
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ImeAnchoringScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _ImeAnchoringScrollPosition extends ScrollPositionWithSingleContext {
  _ImeAnchoringScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  double _pendingImeCorrection = 0;

  void queueImeCorrection(double delta, double followThreshold) {
    if (!hasPixels || !haveDimensions) return;
    if (maxScrollExtent - pixels > followThreshold) return;
    _pendingImeCorrection += delta;
  }

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    if (_pendingImeCorrection != 0) {
      final target = (pixels + _pendingImeCorrection).clamp(
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
      _pendingImeCorrection = 0;
      if (target != pixels) {
        correctPixels(target);
        return false;
      }
    }
    return super.correctForNewDimensions(oldPosition, newPosition);
  }
}
