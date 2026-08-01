import 'package:flutter/material.dart';

import 'paper_theme_color.dart';
import 'theme_preference_repository.dart';

/// 全局主题状态：当前主题色。切换后通知 MaterialApp 重建。
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  PaperThemeColor _color = PaperThemeColor.pink;
  ThemePreferenceRepository? _repository;
  Future<void> _writeQueue = Future.value();
  String? _persistenceError;

  PaperThemeColor get color => _color;
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
      _color = await repository.load() ?? PaperThemeColor.pink;
      _persistenceError = null;
    } on ThemePreferencePersistenceException catch (error) {
      _persistenceError = error.message;
    }
    notifyListeners();
  }

  void setColor(PaperThemeColor color) {
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
      }
      notifyListeners();
    });
  }

  Future<void> flushPendingWrites() => _writeQueue;
}
