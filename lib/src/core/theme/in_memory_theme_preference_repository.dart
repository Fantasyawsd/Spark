import 'paper_theme_color.dart';
import 'theme_preference_repository.dart';

class InMemoryThemePreferenceRepository implements ThemePreferenceRepository {
  InMemoryThemePreferenceRepository([this._color]);

  PaperThemeColor? _color;

  @override
  Future<PaperThemeColor?> load() async => _color;

  @override
  Future<void> save(PaperThemeColor color) async => _color = color;
}
