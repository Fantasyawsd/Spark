import 'package:flutter/material.dart';

/// 可持久化的强调色。保留枚举名称，兼容已有用户偏好。
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
    Color(0xFF228BFF),
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
    '火花橙',
    Color(0xFFB84B2F),
    Color(0xFFF3A589),
    Color(0xFFF9E8DF),
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
