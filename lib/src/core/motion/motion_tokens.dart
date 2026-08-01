import 'package:flutter/material.dart';

abstract final class MotionTokens {
  static const pageDuration = Duration(milliseconds: 300);
  static const tabDuration = Duration(milliseconds: 220);
  static const sheetDuration = Duration(milliseconds: 250);
  static const feedbackDuration = Duration(milliseconds: 140);
  static const splashDuration = Duration(milliseconds: 650);

  static const pageCurve = Curves.easeOutCubic;
  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : value;
  }
}
