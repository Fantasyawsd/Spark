import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/core/storage/local_json_store.dart';
import 'package:paperflow/src/core/theme/file_theme_preference_repository.dart';

void main() {
  test('persists and reloads the selected theme color', () async {
    final repository = InMemoryThemePreferenceRepository();
    final controller = ThemeController.instance;
    await controller.configure(repository);

    controller.setColor(PaperThemeColor.blue);
    await controller.flushPendingWrites();
    await controller.configure(InMemoryThemePreferenceRepository());
    await controller.configure(repository);
    await controller.reload();

    expect(controller.color, PaperThemeColor.blue);
  });

  test('reload restores the default after local preferences are cleared',
      () async {
    final repository = InMemoryThemePreferenceRepository(PaperThemeColor.green);
    final controller = ThemeController.instance;
    await controller.configure(repository);
    expect(controller.color, PaperThemeColor.green);

    final clearedRepository = InMemoryThemePreferenceRepository();
    await controller.configure(clearedRepository);

    expect(controller.color, PaperThemeColor.pink);
  });

  test('file repository restores the color from versioned storage', () async {
    final directory = await Directory.systemTemp.createTemp(
      'paperflow-theme-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}theme.json',
    );
    FileThemePreferenceRepository repository() => FileThemePreferenceRepository(
          store: LocalJsonStore(fileName: 'unused.json', file: file),
        );

    await repository().save(PaperThemeColor.purple);

    expect(await repository().load(), PaperThemeColor.purple);
  });
}
