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

  /// 暖纸色表面；强调色独立于中性色，继续支持已有主题选择。
  factory SparkPalette.light([
    SparkThemeColor accentColor = SparkThemeColor.orange,
  ]) {
    return SparkPalette(
      primary: accentColor.value,
      primarySoft: accentColor.soft,
      primaryPale: accentColor.pale,
      ink: const Color(0xFF262A28),
      muted: const Color(0xFF6F746F),
      subtle: const Color(0xFF81867F),
      foregroundTertiary: const Color(0xFF767C73),
      foregroundDisabled: const Color(0xFFB8BEB3),
      line: const Color(0xFFE1E3DA),
      lineStrong: const Color(0xFFC5CCBD),
      canvas: const Color(0xFFF6F4EF),
      card: const Color(0xFFFFFDF9),
      popover: const Color(0xFFF1F0EA),
      surfaceMuted: const Color(0xFFEEEFE8),
      surfaceStrong: const Color(0xFFE3E6DC),
      accent: const Color(0xFFEEEFE8),
      accentForeground: const Color(0xFF262A28),
      blue: const Color(0xFF007AFF),
      purple: const Color(0xFFAF52DE),
      green: const Color(0xFF248A3D),
      orange: const Color(0xFFC93400),
      danger: const Color(0xFFFF3B30),
      dangerSoft: const Color(0xFFFFE5E3),
      dangerBorder: const Color(0xFFF5B5B0),
      warning: const Color(0xFFB25000),
      barrier: const Color(0x663C3C43),
    );
  }

  /// 深灰绿阅读表面；柔和强调色由卡片表面派生。
  factory SparkPalette.dark([
    SparkThemeColor accentColor = SparkThemeColor.orange,
  ]) {
    const darkCard = Color(0xFF1D2320);
    return SparkPalette(
      primary: accentColor.darkValue,
      primarySoft: Color.alphaBlend(
        accentColor.darkValue.withValues(alpha: 0.28),
        darkCard,
      ),
      primaryPale: Color.alphaBlend(
        accentColor.darkValue.withValues(alpha: 0.14),
        darkCard,
      ),
      ink: const Color(0xFFECEEE8),
      muted: const Color(0xFFA6AEA6),
      subtle: const Color(0xFF8B978C),
      foregroundTertiary: const Color(0xFF8B978C),
      foregroundDisabled: const Color(0xFF566158),
      line: const Color(0xFF343E36),
      lineStrong: const Color(0xFF465348),
      canvas: const Color(0xFF171C19),
      card: darkCard,
      popover: const Color(0xFF252D27),
      surfaceMuted: const Color(0xFF262E28),
      surfaceStrong: const Color(0xFF333E35),
      accent: const Color(0xFF2E3830),
      accentForeground: const Color(0xFFECEEE8),
      blue: const Color(0xFF0A84FF),
      purple: const Color(0xFFBF5AF2),
      green: const Color(0xFF30D158),
      orange: const Color(0xFFFF9F0A),
      danger: const Color(0xFFFF453A),
      dangerSoft: const Color(0xFF3A1512),
      dangerBorder: Color.alphaBlend(
        const Color(0xFFFF453A).withValues(alpha: 0.5),
        darkCard,
      ),
      warning: const Color(0xFFFF9F0A),
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

  /// Filled controls use a quieter orange in the dark palette.
  Color get actionBackground => primary == SparkThemeColor.orange.darkValue
      ? const Color(0xFFE2A087)
      : primary;

  Color get onPrimary => _contentColor(primary);
  Color get onAction => _contentColor(actionBackground);

  static Color _contentColor(Color background) {
    final luminance = background.computeLuminance();
    if (luminance >= 0.45) return const Color(0xFF291F1A);
    return 1.05 / (luminance + 0.05) >= 4.5 ? Colors.white : Colors.black;
  }

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
