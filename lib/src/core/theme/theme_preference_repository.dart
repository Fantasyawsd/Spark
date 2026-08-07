import 'spark_theme_color.dart';

abstract interface class ThemePreferenceRepository {
  Future<SparkThemeColor?> load();

  Future<void> save(SparkThemeColor color);
}

class ThemePreferencePersistenceException implements Exception {
  const ThemePreferencePersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
