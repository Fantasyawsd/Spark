import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/core/theme/in_memory_theme_preference_repository.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/core/theme/file_theme_preference_repository.dart';

void main() {
  test('persists and reloads the selected theme color', () async {
    final repository = InMemoryThemePreferenceRepository();
    final controller = ThemeController.instance;
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
    final controller = ThemeController.instance;
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

  test('a failed theme write does not block later changes', () async {
    final repository = _FailsOnceThemePreferenceRepository();
    final controller = ThemeController.instance;
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
}
