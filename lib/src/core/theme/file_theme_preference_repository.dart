import '../storage/local_json_store.dart';
import '../storage/versioned_local_json_store.dart';
import 'spark_theme_color.dart';
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
  Future<SparkThemeColor?> load() async {
    try {
      final json = await _store.readMap();
      final name = json?['color'];
      if (name is! String) return null;
      return SparkThemeColor.values
          .where((color) => color.name == name)
          .firstOrNull;
    } catch (error) {
      throw ThemePreferencePersistenceException('无法读取主题设置。', error);
    }
  }

  @override
  Future<void> save(SparkThemeColor color) async {
    await _writeKey('color', color.name);
  }

  @override
  Future<AppThemeMode?> loadMode() async {
    try {
      final json = await _store.readMap();
      final name = json?['mode'];
      if (name is! String) return null;
      return AppThemeMode.values.where((mode) => mode.name == name).firstOrNull;
    } catch (error) {
      throw ThemePreferencePersistenceException('无法读取主题设置。', error);
    }
  }

  @override
  Future<void> saveMode(AppThemeMode mode) async {
    await _writeKey('mode', mode.name);
  }

  /// 读-改-写单个键，保留其余键（color / mode 共存于同一文件）。
  /// 调用方（ThemeController 写队列）已串行化，不存在并发竞争。
  Future<void> _writeKey(String key, String value) async {
    try {
      final json = await _store.readMap() ?? <String, dynamic>{};
      json[key] = value;
      await _store.writeMap(json);
    } catch (error) {
      throw ThemePreferencePersistenceException('无法保存主题设置。', error);
    }
  }

  static void _validate(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Theme preferences must be an object.');
    }
    final color = payload['color'];
    if (color != null &&
        (color is! String ||
            !SparkThemeColor.values
                .any((candidate) => candidate.name == color))) {
      throw const FormatException('Theme color is invalid.');
    }
    final mode = payload['mode'];
    if (mode != null &&
        (mode is! String ||
            !AppThemeMode.values.any((candidate) => candidate.name == mode))) {
      throw const FormatException('Theme mode is invalid.');
    }
  }
}
