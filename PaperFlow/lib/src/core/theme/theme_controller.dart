import 'package:flutter/material.dart';

/// 可选的主题主色。value 为主色，soft / pale 为其浅色底。
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

/// 全局主题状态：当前主题色。切换后通知 MaterialApp 重建。
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  PaperThemeColor _color = PaperThemeColor.pink;
  PaperThemeColor get color => _color;

  void setColor(PaperThemeColor color) {
    if (color == _color) return;
    _color = color;
    notifyListeners();
  }
}
