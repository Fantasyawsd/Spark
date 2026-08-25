import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'spark_design_tokens.dart';
import 'spark_font_sizes.dart';
import 'spark_palette.dart';
import 'spark_theme_color.dart';

/// 语义颜色访问门面。
///
/// 亮/暗调色板由 [SparkTheme] 经 `ThemeData.extensions` 注入；
/// 在未注入 Spark 主题的兜底场景（如独立 widget 测试）返回亮色调色板。
abstract final class SparkColors {
  static SparkPalette of(BuildContext context) {
    return Theme.of(context).extension<SparkPalette>() ??
        SparkPalette.light(SparkThemeColor.pink);
  }
}

/// `SparkColors.of(context)` 的简写：`context.sparkColors.ink`。
extension SparkColorsContext on BuildContext {
  SparkPalette get sparkColors => SparkColors.of(this);
}

abstract final class SparkTheme {
  static ThemeData light([SparkThemeColor color = SparkThemeColor.pink]) {
    return _themeData(
      SparkPalette.light(color),
      Brightness.light,
    );
  }

  static ThemeData dark([SparkThemeColor color = SparkThemeColor.pink]) {
    return _themeData(
      SparkPalette.dark(color),
      Brightness.dark,
    );
  }

  static ThemeData _themeData(SparkPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    );
    final scheme = generatedScheme.copyWith(
      primary: palette.primary,
      onPrimary: Colors.white,
      primaryContainer: palette.primarySoft,
      onPrimaryContainer: palette.ink,
      secondary: isDark ? palette.blue : SparkThemeColor.blue.value,
      onSecondary: Colors.white,
      secondaryContainer: isDark
          ? Color.alphaBlend(palette.blue.withValues(alpha: 0.28), palette.card)
          : SparkThemeColor.blue.soft,
      onSecondaryContainer: palette.ink,
      error: palette.danger,
      onError: isDark ? Colors.black : Colors.white,
      errorContainer: palette.dangerSoft,
      onErrorContainer: palette.danger,
      surface: palette.card,
      onSurface: palette.ink,
      onSurfaceVariant: palette.muted,
      outline: palette.subtle,
      outlineVariant: palette.line,
      shadow: isDark ? Colors.black : palette.ink,
      scrim: isDark ? Colors.black : palette.ink,
      inverseSurface: palette.ink,
      onInverseSurface: palette.card,
      inversePrimary: palette.primarySoft,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: palette.popover,
      surfaceContainer: palette.surfaceMuted,
      surfaceContainerHigh:
          isDark ? const Color(0xFF323234) : const Color(0xFFECECEF),
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
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: palette.ink,
          fontSize: SparkFontSizes.title,
          fontWeight: FontWeight.w600,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusDialog),
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
        shadowColor: SparkDesignTokens.shadowColorOf(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusOverlay),
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
        focusedBorder: _inputBorder(palette.primary, width: 1.5),
        errorBorder: _inputBorder(palette.danger),
        focusedErrorBorder: _inputBorder(palette.danger, width: 2.0),
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
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusField),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusField),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: TextStyle(
          color: isDark ? palette.card : Colors.white,
          fontSize: SparkFontSizes.bodySmall,
        ),
        actionTextColor: isDark ? palette.primary : palette.primarySoft,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusField),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.primarySoft,
        disabledColor: palette.surfaceMuted,
        side: BorderSide.none,
        shape: const StadiumBorder(),
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
      // iOS 开关签名色：选中轨道固定系统绿，不随强调色变化。
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFF30D158) : const Color(0xFF34C759))
              : (isDark ? const Color(0xFF39393D) : const Color(0xFFE9E9EA)),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  static TextTheme _textTheme(SparkPalette palette) {
    return TextTheme(
      headlineLarge: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.displayLarge,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.display,
        height: 1.18,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.titleSmall,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.bodyLarge,
        height: 1.4,
        fontWeight: FontWeight.w600,
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
      bodySmall: TextStyle(
        color: palette.muted,
        fontSize: SparkFontSizes.footnote,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        color: palette.ink,
        fontSize: SparkFontSizes.body,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: palette.muted,
        fontSize: SparkFontSizes.footnote,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: palette.muted,
        fontSize: SparkFontSizes.caption,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(SparkDesignTokens.radiusField),
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
