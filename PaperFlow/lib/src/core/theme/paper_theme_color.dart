import 'package:flutter/material.dart';

enum PaperThemeColor {
  pink('默认粉', Color(0xFFFF315F), Color(0xFFFFEEF2), Color(0xFFFFF7F9)),
  blue('蓝色', Color(0xFF2B82F6), Color(0xFFEAF3FE), Color(0xFFF5F9FF)),
  purple('紫色', Color(0xFF8E5CF5), Color(0xFFF1EBFE), Color(0xFFF8F5FF)),
  green('绿色', Color(0xFF41C982), Color(0xFFEAFBF2), Color(0xFFF5FDF8)),
  orange('橙色', Color(0xFFFF8A21), Color(0xFFFFF3E8), Color(0xFFFFF9F2));

  const PaperThemeColor(this.label, this.value, this.soft, this.pale);

  final String label;
  final Color value;
  final Color soft;
  final Color pale;
}
