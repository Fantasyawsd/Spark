import 'spark_theme_color.dart';
import 'theme_preference_repository.dart';

class InMemoryThemePreferenceRepository implements ThemePreferenceRepository {
  InMemoryThemePreferenceRepository([this._color]);

  SparkThemeColor? _color;
  AppThemeMode? _mode;

  @override
  Future<SparkThemeColor?> load() async => _color;

  @override
  Future<void> save(SparkThemeColor color) async => _color = color;

  @override
  Future<AppThemeMode?> loadMode() async => _mode;

  @override
  Future<void> saveMode(AppThemeMode mode) async => _mode = mode;
}
