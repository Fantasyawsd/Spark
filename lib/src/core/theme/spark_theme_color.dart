import 'package:flutter/material.dart';

/// iOS 风格强调色枚举。
///
/// value/darkValue 对齐 Apple 系统色（light/dark 变体）；green/orange 取
/// Apple 自家的加深可用变体而非纯系统色，保证作为按钮底色配白字时
/// 在亮色下对比度 ≥ 3:1（Apple 自身 systemBlue 即 4.02 水平）。
enum SparkThemeColor {
  pink(
    '蔷薇',
    Color(0xFFFF2D55),
    Color(0xFFFF375F),
    Color(0xFFFFE8EF),
    Color(0xFFFFF4F7),
  ),
  blue(
    '学术蓝',
    Color(0xFF007AFF),
    Color(0xFF0A84FF),
    Color(0xFFE4EEFF),
    Color(0xFFF2F7FF),
  ),
  purple(
    '鸢尾紫',
    Color(0xFFAF52DE),
    Color(0xFFBF5AF2),
    Color(0xFFF3E8FB),
    Color(0xFFFAF3FD),
  ),
  green(
    '松石绿',
    Color(0xFF248A3D),
    Color(0xFF30D158),
    Color(0xFFE1F2E6),
    Color(0xFFF0FAF3),
  ),
  orange(
    '琥珀',
    Color(0xFFC93400),
    Color(0xFFFF9F0A),
    Color(0xFFFBE9DF),
    Color(0xFFFDF4EE),
  );

  const SparkThemeColor(
      this.label, this.value, this.darkValue, this.soft, this.pale);

  final String label;
  final Color value;

  /// 暗色模式下的提亮变体：保证作为文本/图标色时
  /// 在暗色卡片（#1C1C1E）上的对比度 ≥ 4.5:1。
  final Color darkValue;
  final Color soft;
  final Color pale;
}
