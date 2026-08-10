import 'package:flutter/material.dart';

import 'spark_theme_color.dart';

/// Spark 语义调色板，作为 [ThemeExtension] 注入主题。
///
/// 字段与历史静态常量 `SparkColors` 一一对应；访问入口为
/// `SparkColors.of(context)`（见 spark_theme.dart）。亮/暗两套实例分别由
/// [SparkPalette.light] / [SparkPalette.dark] 工厂构造，强调色容器色
/// （primarySoft / primaryPale）在暗色下按表面色混合派生，
/// 避免为每个强调色手写暗色变体。
class SparkPalette extends ThemeExtension<SparkPalette> {
  const SparkPalette({
    required this.primary,
    required this.primarySoft,
    required this.primaryPale,
    required this.ink,
    required this.muted,
    required this.subtle,
    required this.foregroundTertiary,
    required this.foregroundDisabled,
    required this.line,
    required this.lineStrong,
    required this.canvas,
    required this.card,
    required this.popover,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.accent,
    required this.accentForeground,
    required this.blue,
    required this.purple,
    required this.green,
    required this.orange,
    required this.danger,
    required this.dangerSoft,
    required this.dangerBorder,
    required this.warning,
    required this.barrier,
  });

  /// 亮色 palette；[accentColor] 决定 primary 系列。
  factory SparkPalette.light([
    SparkThemeColor accentColor = SparkThemeColor.pink,
  ]) {
    return SparkPalette(
      primary: accentColor.value,
      primarySoft: accentColor.soft,
      primaryPale: accentColor.pale,
      ink: const Color(0xFF182230),
      muted: const Color(0xFF667085),
      subtle: const Color(0xFF98A2B3),
      foregroundTertiary: const Color(0xFF7C8798),
      foregroundDisabled: const Color(0xFFB6BFCC),
      line: const Color(0xFFE4E7EC),
      lineStrong: const Color(0xFFD0D5DD),
      canvas: const Color(0xFFF7F8FA),
      card: Colors.white,
      popover: const Color(0xFFFCFCFD),
      surfaceMuted: const Color(0xFFF2F4F7),
      surfaceStrong: const Color(0xFFEAECF0),
      accent: const Color(0xFFF0F2F5),
      accentForeground: const Color(0xFF182230),
      blue: const Color(0xFF356FAE),
      purple: const Color(0xFF7256A8),
      green: const Color(0xFF267A65),
      orange: const Color(0xFFAD5A17),
      danger: const Color(0xFFB42318),
      dangerSoft: const Color(0xFFFEF3F2),
      dangerBorder: const Color(0xFFF0B4AE),
      warning: const Color(0xFFB54708),
      barrier: const Color(0x66182230),
    );
  }

  /// 暗色 palette；primarySoft / primaryPale 由强调色按卡片表面混合派生。
  factory SparkPalette.dark([
    SparkThemeColor accentColor = SparkThemeColor.pink,
  ]) {
    const darkCard = Color(0xFF171D27);
    return SparkPalette(
      primary: accentColor.value,
      primarySoft: Color.alphaBlend(
        accentColor.value.withValues(alpha: 0.28),
        darkCard,
      ),
      primaryPale: Color.alphaBlend(
        accentColor.value.withValues(alpha: 0.14),
        darkCard,
      ),
      ink: const Color(0xFFE8ECF2),
      muted: const Color(0xFF98A2B3),
      subtle: const Color(0xFF667085),
      foregroundTertiary: const Color(0xFF7C8798),
      foregroundDisabled: const Color(0xFF525C6A),
      line: const Color(0xFF2A3140),
      lineStrong: const Color(0xFF3A4354),
      canvas: const Color(0xFF10151C),
      card: darkCard,
      popover: const Color(0xFF1B222E),
      surfaceMuted: const Color(0xFF1E2530),
      surfaceStrong: const Color(0xFF28303E),
      accent: const Color(0xFF232B38),
      accentForeground: const Color(0xFFE8ECF2),
      blue: const Color(0xFF6FA3DC),
      purple: const Color(0xFFA58AD0),
      green: const Color(0xFF4FAD92),
      orange: const Color(0xFFD98A4A),
      danger: const Color(0xFFF04438),
      dangerSoft: const Color(0xFF3B1512),
      dangerBorder: const Color(0xFF8C2F25),
      warning: const Color(0xFFF79009),
      barrier: const Color(0x8C000000),
    );
  }

  final Color primary;
  final Color primarySoft;
  final Color primaryPale;
  final Color ink;
  final Color muted;
  final Color subtle;
  final Color foregroundTertiary;
  final Color foregroundDisabled;
  final Color line;
  final Color lineStrong;
  final Color canvas;
  final Color card;
  final Color popover;
  final Color surfaceMuted;
  final Color surfaceStrong;
  final Color accent;
  final Color accentForeground;
  final Color blue;
  final Color purple;
  final Color green;
  final Color orange;
  final Color danger;
  final Color dangerSoft;
  final Color dangerBorder;
  final Color warning;
  final Color barrier;

  @override
  SparkPalette copyWith({
    Color? primary,
    Color? primarySoft,
    Color? primaryPale,
    Color? ink,
    Color? muted,
    Color? subtle,
    Color? foregroundTertiary,
    Color? foregroundDisabled,
    Color? line,
    Color? lineStrong,
    Color? canvas,
    Color? card,
    Color? popover,
    Color? surfaceMuted,
    Color? surfaceStrong,
    Color? accent,
    Color? accentForeground,
    Color? blue,
    Color? purple,
    Color? green,
    Color? orange,
    Color? danger,
    Color? dangerSoft,
    Color? dangerBorder,
    Color? warning,
    Color? barrier,
  }) {
    return SparkPalette(
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryPale: primaryPale ?? this.primaryPale,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      foregroundTertiary: foregroundTertiary ?? this.foregroundTertiary,
      foregroundDisabled: foregroundDisabled ?? this.foregroundDisabled,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      popover: popover ?? this.popover,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      blue: blue ?? this.blue,
      purple: purple ?? this.purple,
      green: green ?? this.green,
      orange: orange ?? this.orange,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      warning: warning ?? this.warning,
      barrier: barrier ?? this.barrier,
    );
  }

  @override
  SparkPalette lerp(SparkPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return SparkPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryPale: Color.lerp(primaryPale, other.primaryPale, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      foregroundTertiary: Color.lerp(
        foregroundTertiary,
        other.foregroundTertiary,
        t,
      )!,
      foregroundDisabled: Color.lerp(
        foregroundDisabled,
        other.foregroundDisabled,
        t,
      )!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      popover: Color.lerp(popover, other.popover, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(
        accentForeground,
        other.accentForeground,
        t,
      )!,
      blue: Color.lerp(blue, other.blue, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      green: Color.lerp(green, other.green, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      barrier: Color.lerp(barrier, other.barrier, t)!,
    );
  }
}
