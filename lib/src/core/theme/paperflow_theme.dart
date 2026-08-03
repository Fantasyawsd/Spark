import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'paperflow_design_tokens.dart';
import 'paper_theme_color.dart';
import 'theme_controller.dart';

abstract final class PaperFlowColors {
  static Color get primary => ThemeController.instance.color.value;
  static Color get primarySoft => ThemeController.instance.color.soft;
  static Color get primaryPale => ThemeController.instance.color.pale;
  static const ink = Color(0xFF182230);
  static const muted = Color(0xFF667085);
  static const subtle = Color(0xFF98A2B3);
  static const foregroundTertiary = Color(0xFF7C8798);
  static const foregroundDisabled = Color(0xFFB6BFCC);
  static const line = Color(0xFFE4E7EC);
  static const lineStrong = Color(0xFFD0D5DD);
  static const canvas = Color(0xFFF7F8FA);
  static const card = Colors.white;
  static const popover = Color(0xFFFCFCFD);
  static const surfaceMuted = Color(0xFFF2F4F7);
  static const surfaceStrong = Color(0xFFEAECF0);
  static const accent = Color(0xFFF0F2F5);
  static const accentForeground = Color(0xFF182230);
  static const blue = Color(0xFF356FAE);
  static const purple = Color(0xFF7256A8);
  static const green = Color(0xFF267A65);
  static const orange = Color(0xFFAD5A17);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFEF3F2);
}

abstract final class PaperFlowTheme {
  static ThemeData light() {
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: PaperFlowColors.primary,
      brightness: Brightness.light,
    );
    final scheme = generatedScheme.copyWith(
      primary: PaperFlowColors.primary,
      onPrimary: Colors.white,
      primaryContainer: PaperFlowColors.primarySoft,
      onPrimaryContainer: PaperFlowColors.ink,
      secondary: PaperThemeColor.blue.value,
      onSecondary: Colors.white,
      secondaryContainer: PaperThemeColor.blue.soft,
      onSecondaryContainer: PaperFlowColors.ink,
      error: PaperFlowColors.danger,
      onError: Colors.white,
      errorContainer: PaperFlowColors.dangerSoft,
      onErrorContainer: PaperFlowColors.danger,
      surface: PaperFlowColors.card,
      onSurface: PaperFlowColors.ink,
      onSurfaceVariant: PaperFlowColors.muted,
      outline: PaperFlowColors.subtle,
      outlineVariant: PaperFlowColors.line,
      shadow: PaperFlowColors.ink,
      scrim: PaperFlowColors.ink,
      inverseSurface: PaperFlowColors.ink,
      onInverseSurface: PaperFlowColors.card,
      inversePrimary: PaperFlowColors.primarySoft,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: PaperFlowColors.card,
      surfaceContainerLow: const Color(0xFFFAFBFC),
      surfaceContainer: PaperFlowColors.surfaceMuted,
      surfaceContainerHigh: const Color(0xFFEEF0F3),
      surfaceContainerHighest: PaperFlowColors.surfaceStrong,
    );
    const textTheme = _textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: PaperFlowColors.canvas,
      canvasColor: PaperFlowColors.canvas,
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Segoe UI',
        'Arial',
      ],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: PaperFlowColors.ink, size: 22),
      appBarTheme: const AppBarTheme(
        backgroundColor: PaperFlowColors.card,
        foregroundColor: PaperFlowColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: PaperFlowColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusLg),
          side: const BorderSide(color: PaperFlowColors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PaperFlowColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radius3Xl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PaperFlowColors.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: PaperFlowColors.card,
        modalBarrierColor: Color(0x66182230),
        elevation: 0,
        modalElevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: PaperFlowColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x1A182230),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusXl),
        ),
        textStyle: const TextStyle(
          color: PaperFlowColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: PaperFlowColors.line,
      dividerTheme: const DividerThemeData(
        color: PaperFlowColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PaperFlowColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: const TextStyle(color: PaperFlowColors.subtle, fontSize: 14),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(PaperFlowColors.primary, width: 1.4),
        errorBorder: _inputBorder(PaperFlowColors.danger),
        focusedErrorBorder: _inputBorder(PaperFlowColors.danger, width: 1.4),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: PaperFlowColors.primary,
        selectionColor: PaperFlowColors.primary.withValues(alpha: 0.18),
        selectionHandleColor: PaperFlowColors.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PaperFlowColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: PaperFlowColors.surfaceStrong,
          disabledForegroundColor: PaperFlowColors.subtle,
          minimumSize: const Size(44, 44),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PaperFlowColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusMd),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PaperFlowColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        actionTextColor: PaperFlowColors.primarySoft,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusLg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PaperFlowColors.surfaceMuted,
        selectedColor: PaperFlowColors.primarySoft,
        disabledColor: PaperFlowColors.surfaceMuted,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusSm),
        ),
        labelStyle: const TextStyle(
          color: PaperFlowColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: PaperFlowColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: PaperFlowColors.muted,
        textColor: PaperFlowColors.ink,
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  static const TextTheme _textTheme = TextTheme(
    headlineLarge: TextStyle(
      color: PaperFlowColors.ink,
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
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
  );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusMd),
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
