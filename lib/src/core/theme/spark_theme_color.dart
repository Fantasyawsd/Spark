import 'package:flutter/material.dart';

enum SparkThemeColor {
  pink('蔷薇', Color(0xFFD13C5F), Color(0xFFFBE9EE), Color(0xFFFFF7F9)),
  blue('学术蓝', Color(0xFF356FAE), Color(0xFFE8F0F8), Color(0xFFF5F8FC)),
  purple('鸢尾紫', Color(0xFF7256A8), Color(0xFFEEEAF6), Color(0xFFF8F6FC)),
  green('松石绿', Color(0xFF267A65), Color(0xFFE6F2EE), Color(0xFFF5FAF8)),
  orange('琥珀', Color(0xFFAD5A17), Color(0xFFF7ECE2), Color(0xFFFCF8F4));

  const SparkThemeColor(this.label, this.value, this.soft, this.pale);

  final String label;
  final Color value;
  final Color soft;
  final Color pale;
}
