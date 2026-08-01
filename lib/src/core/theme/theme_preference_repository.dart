import 'paper_theme_color.dart';

abstract interface class ThemePreferenceRepository {
  Future<PaperThemeColor?> load();

  Future<void> save(PaperThemeColor color);
}

class ThemePreferencePersistenceException implements Exception {
  const ThemePreferencePersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
