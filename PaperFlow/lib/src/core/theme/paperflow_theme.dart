import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme_controller.dart';

abstract final class PaperFlowColors {
  static Color get primary => ThemeController.instance.color.value;
  static Color get primarySoft => ThemeController.instance.color.soft;
  static Color get primaryPale => ThemeController.instance.color.pale;
  static const ink = Color(0xFF10182B);
  static const muted = Color(0xFF737B91);
  static const subtle = Color(0xFFA9AFBC);
  static const line = Color(0xFFE8EAF0);
  static const canvas = Color(0xFFF8F9FC);
  static const card = Colors.white;
  static const blue = Color(0xFF2B82F6);
  static const purple = Color(0xFF8E5CF5);
  static const green = Color(0xFF41C982);
  static const orange = Color(0xFFFF8A21);
}

abstract final class PaperFlowTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: PaperFlowColors.primary,
      brightness: Brightness.light,
      primary: PaperFlowColors.primary,
      surface: PaperFlowColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: PaperFlowColors.canvas,
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Segoe UI',
        'Arial',
      ],
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: PaperFlowColors.ink,
          fontSize: 30,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        headlineMedium: TextStyle(
          color: PaperFlowColors.ink,
          fontSize: 24,
          height: 1.18,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: PaperFlowColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: PaperFlowColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: PaperFlowColors.ink,
          fontSize: 15,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          color: PaperFlowColors.muted,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      dividerColor: PaperFlowColors.line,
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// 返回当前平台可用的 CJK 主字体。
  ///
  /// 中英文混排时，英文默认走 Roboto / SF，中文 fallback 到中文字体
  /// （微软雅黑 / PingFang 等），两套字体的行高与基线规则不同，
  /// 会造成视觉错位。统一到 CJK 字体后，中英文字符共用同一基线，
  /// 顶栏分类等混排文字即对齐。
  static String? platformCjkFontFamily() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'Microsoft YaHei';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'PingFang SC';
      case TargetPlatform.linux:
        return 'Noto Sans CJK SC';
      case TargetPlatform.android:
      default:
        // Android 系统自带 Noto CJK 字体，默认混排基线差异小，交由系统处理。
        return null;
    }
  }
}

const paperFlowCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x1015213A),
    blurRadius: 24,
    offset: Offset(0, 10),
  ),
];
