import 'package:flutter/material.dart';

import 'spark_theme_color.dart';
import 'theme_preference_repository.dart';

/// 全局主题状态：当前主题色。切换后通知 MaterialApp 重建。
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  SparkThemeColor _color = SparkThemeColor.pink;
  ThemePreferenceRepository? _repository;
  Future<void> _writeQueue = Future.value();
  String? _persistenceError;

  SparkThemeColor get color => _color;
  String? get persistenceError => _persistenceError;

  Future<void> configure(ThemePreferenceRepository repository) {
    if (identical(_repository, repository)) return Future.value();
    _repository = repository;
    return reload();
  }

  Future<void> initialize() => reload();

  Future<void> reload() async {
    await flushPendingWrites();
    final repository = _repository;
    if (repository == null) return;
    try {
      _color = await repository.load() ?? SparkThemeColor.pink;
      _persistenceError = null;
    } on ThemePreferencePersistenceException catch (error) {
      _persistenceError = error.message;
    }
    notifyListeners();
  }

  void setColor(SparkThemeColor color) {
    if (color == _color) return;
    _color = color;
    notifyListeners();
    final repository = _repository;
    if (repository == null) return;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(color);
        _persistenceError = null;
      } on ThemePreferencePersistenceException catch (error) {
        _persistenceError = error.message;
      } catch (error) {
        _persistenceError = '主题设置保存失败：$error';
      }
      notifyListeners();
    });
  }

  Future<void> flushPendingWrites() => _writeQueue;
}
