import 'spark_theme_color.dart';
import 'theme_preference_repository.dart';

class InMemoryThemePreferenceRepository implements ThemePreferenceRepository {
  InMemoryThemePreferenceRepository([this._color]);

  SparkThemeColor? _color;

  @override
  Future<SparkThemeColor?> load() async => _color;

  @override
  Future<void> save(SparkThemeColor color) async => _color = color;
}
