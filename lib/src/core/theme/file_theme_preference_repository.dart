import '../storage/local_json_store.dart';
import '../storage/versioned_local_json_store.dart';
import 'paper_theme_color.dart';
import 'theme_preference_repository.dart';

class FileThemePreferenceRepository implements ThemePreferenceRepository {
  FileThemePreferenceRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'theme_preferences.json'),
          schemaId: 'core.theme-preferences',
          validatePayload: _validate,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<PaperThemeColor?> load() async {
    try {
      final json = await _store.readMap();
      final name = json?['color'];
      if (name is! String) return null;
      return PaperThemeColor.values
          .where((color) => color.name == name)
          .firstOrNull;
    } catch (error) {
      throw ThemePreferencePersistenceException('无法读取主题设置。', error);
    }
  }

  @override
  Future<void> save(PaperThemeColor color) async {
    try {
      await _store.writeMap({'color': color.name});
    } catch (error) {
      throw ThemePreferencePersistenceException('无法保存主题设置。', error);
    }
  }

  static void _validate(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Theme preferences must be an object.');
    }
    final color = payload['color'];
    if (color is! String ||
        !PaperThemeColor.values.any((candidate) => candidate.name == color)) {
      throw const FormatException('Theme color is invalid.');
    }
  }
}
