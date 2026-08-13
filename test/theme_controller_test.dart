import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/core/theme/in_memory_theme_preference_repository.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/core/theme/file_theme_preference_repository.dart';

void main() {
  test('theme controller instances keep independent state and queues',
      () async {
    final first = ThemeController();
    final second = ThemeController();
    await first.configure(InMemoryThemePreferenceRepository());
    await second.configure(InMemoryThemePreferenceRepository());

    first.setColor(SparkThemeColor.blue);
    await first.flushPendingWrites();

    expect(first.color, SparkThemeColor.blue);
    expect(second.color, SparkThemeColor.pink);
    expect(first, isNot(same(second)));
  });

  test('persists and reloads the selected theme color', () async {
    final repository = InMemoryThemePreferenceRepository();
    final controller = ThemeController();
    await controller.configure(repository);

    controller.setColor(SparkThemeColor.blue);
    await controller.flushPendingWrites();
    await controller.configure(InMemoryThemePreferenceRepository());
    await controller.configure(repository);
    await controller.reload();

    expect(controller.color, SparkThemeColor.blue);
  });

  test('reload restores the default after local preferences are cleared',
      () async {
    final repository = InMemoryThemePreferenceRepository(SparkThemeColor.green);
    final controller = ThemeController();
    await controller.configure(repository);
    expect(controller.color, SparkThemeColor.green);

    final clearedRepository = InMemoryThemePreferenceRepository();
    await controller.configure(clearedRepository);

    expect(controller.color, SparkThemeColor.pink);
  });

  test('file repository restores the color from versioned storage', () async {
    final directory = await Directory.systemTemp.createTemp(
      'spark-theme-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}theme.json',
    );
    FileThemePreferenceRepository repository() => FileThemePreferenceRepository(
          store: LocalJsonStore(fileName: 'unused.json', file: file),
        );

    await repository().save(SparkThemeColor.purple);

    expect(await repository().load(), SparkThemeColor.purple);
  });

  test('persists and reloads the selected theme mode', () async {
    final repository = InMemoryThemePreferenceRepository();
    final controller = ThemeController();
    await controller.configure(repository);

    controller.setMode(AppThemeMode.dark);
    await controller.flushPendingWrites();
    await controller.configure(InMemoryThemePreferenceRepository());
    await controller.configure(repository);
    await controller.reload();

    expect(controller.mode, AppThemeMode.dark);

    controller.setMode(AppThemeMode.system);
    await controller.flushPendingWrites();
  });

  test('file repository keeps color and mode in one document', () async {
    final directory = await Directory.systemTemp.createTemp(
      'spark-theme-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}theme.json',
    );
    FileThemePreferenceRepository repository() => FileThemePreferenceRepository(
          store: LocalJsonStore(fileName: 'unused.json', file: file),
        );

    await repository().save(SparkThemeColor.purple);
    await repository().saveMode(AppThemeMode.dark);

    expect(await repository().load(), SparkThemeColor.purple);
    expect(await repository().loadMode(), AppThemeMode.dark);
  });

  test('a failed theme write does not block later changes', () async {
    final repository = _FailsOnceThemePreferenceRepository();
    final controller = ThemeController();
    await controller.configure(repository);

    controller.setColor(SparkThemeColor.blue);
    await controller.flushPendingWrites();
    expect(controller.persistenceError, isNotNull);

    controller.setColor(SparkThemeColor.green);
    await controller.flushPendingWrites();

    expect(repository.savedColor, SparkThemeColor.green);
    expect(controller.persistenceError, isNull);
  });
}

class _FailsOnceThemePreferenceRepository implements ThemePreferenceRepository {
  var _shouldFail = true;
  SparkThemeColor? savedColor;

  @override
  Future<SparkThemeColor?> load() async => null;

  @override
  Future<void> save(SparkThemeColor color) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('simulated write failure');
    }
    savedColor = color;
  }

  @override
  Future<AppThemeMode?> loadMode() async => null;

  @override
  Future<void> saveMode(AppThemeMode mode) async {}
}
