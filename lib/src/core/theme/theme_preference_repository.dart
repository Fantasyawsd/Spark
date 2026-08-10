import 'spark_theme_color.dart';

/// 应用外观模式。持久化于主题偏好存储，`null`（缺失）视为 [system]。
enum AppThemeMode { system, light, dark }

abstract interface class ThemePreferenceRepository {
  Future<SparkThemeColor?> load();

  Future<void> save(SparkThemeColor color);

  Future<AppThemeMode?> loadMode();

  Future<void> saveMode(AppThemeMode mode);
}

class ThemePreferencePersistenceException implements Exception {
  const ThemePreferencePersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
