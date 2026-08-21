import 'package:flutter/material.dart';

abstract final class MotionTokens {
  static const microDuration = Duration(milliseconds: 90);
  static const pageDuration = Duration(milliseconds: 300);
  static const tabDuration = Duration(milliseconds: 220);
  static const sheetDuration = Duration(milliseconds: 250);
  static const feedbackDuration = Duration(milliseconds: 140);
  static const entryDuration = Duration(milliseconds: 220);
  static const popoverDuration = Duration(milliseconds: 260);
  static const splashDuration = Duration(milliseconds: 650);

  static const pageCurve = Curves.easeOutCubic;
  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  /// 选中/点赞等需要弹性回落的微交互。
  static const springCurve = Curves.easeOutBack;

  /// M3 emphasized easing：大幅面转场与显式运动。
  static const emphasizedCurve = Curves.easeInOutCubicEmphasized;

  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : value;
  }
}
