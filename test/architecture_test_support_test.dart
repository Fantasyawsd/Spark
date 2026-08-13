import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/architecture_test_support.dart';

void main() {
  late Directory packageRoot;

  setUp(() {
    packageRoot = Directory.systemTemp.createTempSync('spark_architecture_');
  });

  tearDown(() {
    packageRoot.deleteSync(recursive: true);
  });

  ArchitectureSourceGraph graph() => ArchitectureSourceGraph(
        sourceRoot: Directory('${packageRoot.path}/lib/src'),
        packageRoot: packageRoot,
      );

  File source(String path, String contents) {
    final file = File('${packageRoot.path}/lib/src/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
    return file;
  }

  test('detects every forbidden same-feature layer direction', () {
    source(
      'features/papers/presentation/screen.dart',
      "import '../data/repository.dart';\n",
    );
    source(
      'features/papers/application/use_case.dart',
      "import '../data/repository.dart';\n"
          "import '../presentation/screen.dart';\n",
    );
    source(
      'features/papers/data/repository.dart',
      "import '../application/use_case.dart';\n"
          "import '../presentation/screen.dart';\n",
    );
    source(
      'features/papers/domain/paper.dart',
      "import '../application/use_case.dart';\n"
          "import '../data/repository.dart';\n"
          "import '../presentation/screen.dart';\n",
    );

    final violations = graph().sameFeatureLayerViolations();

    expect(violations, hasLength(8));
    expect(
      violations,
      contains(contains('presentation/screen.dart -> ../data/repository.dart')),
    );
    expect(
      violations,
      contains(contains('domain/paper.dart -> ../presentation/screen.dart')),
    );
  });

  test('allows the documented inward same-feature directions', () {
    source(
      'features/papers/presentation/screen.dart',
      "import '../application/use_case.dart';\n"
          "import '../domain/paper.dart';\n",
    );
    source(
      'features/papers/application/use_case.dart',
      "import '../domain/paper.dart';\n",
    );
    source(
      'features/papers/data/repository.dart',
      "import '../domain/paper.dart';\n",
    );
    source('features/papers/domain/paper.dart', 'class Paper {}\n');

    expect(graph().sameFeatureLayerViolations(), isEmpty);
  });

  test('domain rejects infrastructure and unapproved packages by default', () {
    source(
      'features/papers/domain/paper.dart',
      "import 'dart:async';\n"
          "import 'dart:io';\n"
          "import 'package:sqflite/sqflite.dart';\n"
          "import 'package:path_provider/path_provider.dart';\n"
          "import 'package:shared_preferences/shared_preferences.dart';\n"
          "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\n"
          "import 'package:collection/collection.dart';\n",
    );

    final violations = graph().domainDependencyViolations();

    expect(violations, hasLength(6));
    for (final forbidden in [
      'dart:io',
      'package:sqflite/',
      'package:path_provider/',
      'package:shared_preferences/',
      'package:flutter_secure_storage/',
      'package:collection/',
    ]) {
      expect(violations, contains(contains(forbidden)));
    }
    expect(violations, isNot(contains(contains('dart:async'))));
  });

  test('domain rejects internal non-domain source through a barrel', () {
    source(
      'features/papers/domain/paper.dart',
      "import 'package:spark/src/core/storage/store.dart';\n",
    );
    source('core/storage/store.dart', 'class Store {}\n');

    final violations = graph().domainDependencyViolations();

    expect(violations, hasLength(1));
    expect(violations.single, contains('core/storage/store.dart'));
  });

  test('domain permits an external package only when explicitly allowed', () {
    source(
      'features/papers/domain/paper.dart',
      "import 'package:meta/meta.dart';\n",
    );

    expect(graph().domainDependencyViolations(), hasLength(1));
    expect(
      graph().domainDependencyViolations(
        allowedExternalPackages: const {'meta'},
      ),
      isEmpty,
    );
  });

  test('reports a real multi-file import and export cycle', () {
    source('a.dart', "import 'b.dart';\n");
    source('b.dart', "export 'c.dart';\n");
    source('c.dart', "import 'a.dart';\n");

    final cycles = graph().importCycles();

    expect(cycles, hasLength(1));
    expect(cycles.single, contains('lib/src/a.dart -> lib/src/b.dart'));
    expect(cycles.single, contains('lib/src/b.dart -> lib/src/c.dart'));
    expect(cycles.single, contains('lib/src/c.dart -> lib/src/a.dart'));
  });

  test('accepts an acyclic source graph', () {
    source('a.dart', "import 'b.dart';\n");
    source('b.dart', "export 'c.dart';\n");
    source('c.dart', 'class Leaf {}\n');

    expect(graph().importCycles(), isEmpty);
  });

  test('counts feature use transitively through core widget wrappers', () {
    source('core/widgets/base.dart', 'class Base {}\n');
    source(
      'core/widgets/wrapper.dart',
      "import 'base.dart';\nclass Wrapper {}\n",
    );
    source(
      'features/papers/presentation/screen.dart',
      "import '../../../core/widgets/wrapper.dart';\n",
    );
    source(
      'features/chat/presentation/screen.dart',
      "import '../../../core/widgets/wrapper.dart';\n",
    );

    expect(graph().coreWidgetReuseViolations(), isEmpty);
  });

  test('reports a core widget used by only one feature', () {
    source('core/widgets/topic.dart', 'class Topic {}\n');
    source(
      'features/papers/presentation/screen.dart',
      "import '../../../core/widgets/topic.dart';\n",
    );

    final violations = graph().coreWidgetReuseViolations();

    expect(violations, hasLength(1));
    expect(violations.single, contains('features: papers'));
    expect(violations.single, contains('requires at least 2'));
  });

  test('does not count test imports or an unused core barrel as feature use',
      () {
    source('core/widgets/orphan.dart', 'class Orphan {}\n');
    source(
      'core/widget_barrel.dart',
      "export 'widgets/orphan.dart';\n",
    );
    final testConsumer = File('${packageRoot.path}/test/consumer.dart');
    testConsumer.parent.createSync(recursive: true);
    testConsumer.writeAsStringSync(
      "import 'package:spark/src/core/widgets/orphan.dart';\n",
    );

    final violations = graph().coreWidgetReuseViolations();

    expect(violations, hasLength(1));
    expect(violations.single, contains('features: none'));
  });

  test('parses every branch of a conditional import', () {
    final entry = source(
      'entry.dart',
      "import 'fallback.dart' if (dart.library.io) 'native.dart';\n",
    );
    source('fallback.dart', 'class Fallback {}\n');
    source('native.dart', 'class Native {}\n');

    expect(graph().directives(entry), ['fallback.dart', 'native.dart']);
  });
}
