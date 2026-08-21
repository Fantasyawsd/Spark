import 'package:flutter/material.dart';

/// Cherry Studio-inspired structural tokens for Spark.
///
/// The reference uses surface layering and hairline borders as the default
/// depth system. Shadows are intentionally limited to interactive and
/// floating surfaces so the reading canvas stays quiet.
abstract final class SparkDesignTokens {
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

  /// 控件级圆角：按钮、输入框、搜索框。
  static const radiusField = 12.0;

  static const radiusLg = 10.0;
  static const radiusXl = 14.0;

  /// 卡片级圆角：SurfaceCard、列表卡、网格卡。
  static const radiusCard = 18.0;

  /// 浮层级圆角：dialog、sheet、popup menu。
  static const radiusOverlay = 22.0;

  static const radius2Xl = 18.0;
  static const radius3Xl = 22.0;

  static const borderWidth = 1.0;

  /// 阴影基色：亮色下用墨蓝黑，暗色下用纯黑系保证可见。
  static Color shadowColorOf(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color(0x14182230),
        Brightness.dark => const Color(0x66000000),
      };

  /// level 1 微浮：列表卡、会话卡。三层「接触 + 环境 + 远投影」组合。
  static List<BoxShadow> interactiveShadowFor(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const [
            BoxShadow(
                color: Color(0x0A182230), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(
                color: Color(0x14182230), blurRadius: 8, offset: Offset(0, 2)),
            BoxShadow(
                color: Color(0x0A182230), blurRadius: 16, offset: Offset(0, 4)),
          ],
        Brightness.dark => const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(
                color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 2)),
            BoxShadow(
                color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
          ],
      };

  /// level 2 悬浮：悬浮按钮、吸附栏、玻璃底栏。
  static List<BoxShadow> floatingShadowFor(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const [
            BoxShadow(
                color: Color(0x14182230), blurRadius: 8, offset: Offset(0, 4)),
            BoxShadow(
                color: Color(0x1F182230), blurRadius: 24, offset: Offset(0, 8)),
            BoxShadow(
                color: Color(0x14233030),
                blurRadius: 48,
                offset: Offset(0, 16)),
          ],
        Brightness.dark => const [
            BoxShadow(
                color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 4)),
            BoxShadow(
                color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
            BoxShadow(
                color: Color(0x59000000),
                blurRadius: 48,
                offset: Offset(0, 16)),
          ],
      };

  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : value;
  }
}
