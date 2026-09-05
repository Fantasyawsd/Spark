import 'package:flutter/material.dart';

/// iOS HIG-inspired structural tokens for Spark.
///
/// Depth comes from surface layering (canvas vs card fill) rather than
/// borders; shadows are kept minimal and reserved for interactive and
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

  /// 卡片级圆角：SurfaceCard、列表卡、网格卡（iOS inset grouped 卡）。
  static const radiusCard = 16.0;

  /// 浮层级圆角：sheet、popup menu。
  static const radiusOverlay = 20.0;

  /// iOS alert 风格对话框圆角。
  static const radiusDialog = 14.0;

  static const radius2Xl = 18.0;
  static const radius3Xl = 22.0;

  /// 聊天气泡朝向说话人一侧收小的尾巴圆角。
  static const bubbleTail = 6.0;

  static const borderWidth = 1.0;

  /// 阴影基色：中性黑，亮色下低透明度保证安静。
  static Color shadowColorOf(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color(0x14000000),
        Brightness.dark => const Color(0x66000000),
      };

  /// level 1 微浮：列表卡、会话卡。iOS 式近扁平，仅保留一层轻接触影。
  static List<BoxShadow> interactiveShadowFor(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        Brightness.dark => const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
      };

  /// level 2 悬浮：悬浮按钮、吸附栏、玻璃底栏。
  static List<BoxShadow> floatingShadowFor(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
            BoxShadow(
                color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        Brightness.dark => const [
            BoxShadow(
                color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 4)),
            BoxShadow(
                color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
      };

  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : value;
  }
}
