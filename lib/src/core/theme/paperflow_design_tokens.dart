import 'package:flutter/material.dart';

/// Cherry Studio-inspired structural tokens for PaperFlow.
///
/// The reference uses surface layering and hairline borders as the default
/// depth system. Shadows are intentionally limited to interactive and
/// floating surfaces so the reading canvas stays quiet.
abstract final class PaperFlowDesignTokens {
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  static const radiusXs = 2.0;
  static const radiusSm = 6.0;
  static const radiusMd = 8.0;
  static const radiusLg = 10.0;
  static const radiusXl = 14.0;
  static const radius2Xl = 18.0;
  static const radius3Xl = 22.0;

  static const borderWidth = 1.0;
  static const interactiveShadow = <BoxShadow>[
    BoxShadow(color: Color(0x14182230), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const floatingShadow = <BoxShadow>[
    BoxShadow(color: Color(0x24182230), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : value;
  }
}
