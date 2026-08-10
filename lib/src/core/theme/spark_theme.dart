import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'spark_design_tokens.dart';
import 'spark_font_sizes.dart';
import 'spark_palette.dart';
import 'spark_theme_color.dart';
import 'theme_controller.dart';

/// 语义颜色访问门面。
///
/// 亮/暗调色板由 [SparkTheme] 经 `ThemeData.extensions` 注入；
/// 在未注入 Spark 主题的兜底场景（如独立 widget 测试）返回亮色调色板，
/// 强调色取自 [ThemeController] 当前值。
abstract final class SparkColors {
  static SparkPalette of(BuildContext context) {
    return Theme.of(context).extension<SparkPalette>() ??
        SparkPalette.light(ThemeController.instance.color);
  }
}

/// `SparkColors.of(context)` 的简写：`context.sparkColors.ink`。
extension SparkColorsContext on BuildContext {
  SparkPalette get sparkColors => SparkColors.of(this);
}

abstract final class SparkTheme {
  static ThemeData light() {
    final palette = SparkPalette.light(ThemeController.instance.color);
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: Brightness.light,
    );
    final scheme = generatedScheme.copyWith(
      primary: palette.primary,
      onPrimary: Colors.white,
      primaryContainer: palette.primarySoft,
      onPrimaryContainer: palette.ink,
      secondary: SparkThemeColor.blue.value,
      onSecondary: Colors.white,
      secondaryContainer: SparkThemeColor.blue.soft,
      onSecondaryContainer: palette.ink,
      error: palette.danger,
      onError: Colors.white,
      errorContainer: palette.dangerSoft,
      onErrorContainer: palette.danger,
      surface: palette.card,
      onSurface: palette.ink,
      onSurfaceVariant: palette.muted,
      outline: palette.subtle,
      outlineVariant: palette.line,
      shadow: palette.ink,
      scrim: palette.ink,
      inverseSurface: palette.ink,
      onInverseSurface: palette.card,
      inversePrimary: palette.primarySoft,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: const Color(0xFFFAFBFC),
      surfaceContainer: palette.surfaceMuted,
      surfaceContainerHigh: const Color(0xFFEEF0F3),
      surfaceContainerHighest: palette.surfaceStrong,
    );
    final textTheme = _textTheme(palette);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Segoe UI',
        'Arial',
      ],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: palette.ink, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.card,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
          side: BorderSide(color: palette.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radius3Xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.card,
        modalBarrierColor: palette.barrier,
        elevation: 0,
        modalElevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x1A182230),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusXl),
        ),
        textStyle: TextStyle(
          color: palette.ink,
          fontSize: SparkFontSizes.bodySmall,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: palette.line,
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: TextStyle(
          color: palette.subtle,
          fontSize: SparkFontSizes.body,
        ),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(palette.primary, width: 1.4),
        errorBorder: _inputBorder(palette.danger),
        focusedErrorBorder: _inputBorder(palette.danger, width: 1.4),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.primary,
        selectionColor: palette.primary.withValues(alpha: 0.18),
        selectionHandleColor: palette.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.surfaceStrong,
          disabledForegroundColor: palette.subtle,
          minimumSize: const Size(44, 44),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: SparkFontSizes.bodySmall,
        ),
        actionTextColor: palette.primarySoft,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.primarySoft,
        disabledColor: palette.surfaceMuted,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusSm),
        ),
        labelStyle: TextStyle(
          color: palette.ink,
          fontSize: SparkFontSizes.footnote,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: palette.primary,
          fontSize: SparkFontSizes.footnote,
          fontWeight: FontWeight.w700,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.muted,
        textColor: palette.ink,
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  static TextTheme _textTheme(SparkPalette palette) {
    return TextTheme(
      headlineLarge: TextStyle(
        color: palette.ink,
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.display,
        height: 1.18,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.headlineSmall,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.titleSmall,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.bodyLarge,
        height: 1.55,
      ),
      bodyMedium: TextStyle(
        color: palette.muted,
        fontSize: SparkFontSizes.bodySmall,
        height: 1.45,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
      borderSide: BorderSide(color: color, width: width),
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
