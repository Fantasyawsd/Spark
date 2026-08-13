import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/architecture_test_support.dart';

void main() {
  final graph = ArchitectureSourceGraph(
    sourceRoot: Directory('lib/src'),
    packageRoot: Directory.current,
  );

  test('same feature layers only depend inward', () {
    final violations = graph.sameFeatureLayerViolations();

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('feature data layers do not depend on application layers', () {
    final dataFiles = graph.sourceFiles.where(
      (file) => graph.featureLayer(file) == 'data',
    );
    final violations = graph.importsMatching(
      dataFiles,
      (imported) => graph.featureLayer(imported) == 'application',
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('feature domain layers remain framework and infrastructure free', () {
    final violations = graph.domainDependencyViolations();

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('lib/src import graph remains acyclic', () {
    final violations = graph.importCycles();

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('core does not depend on business features', () {
    final coreFiles = graph.sourceFiles.where(
      (file) => graph.pathSegments(file).contains('core'),
    );
    final violations = graph.importsMatching(
      coreFiles,
      (imported) => graph.pathSegments(imported).contains('features'),
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('core widgets are used by at least two business features', () {
    final violations = graph.coreWidgetReuseViolations();

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('features do not deep import sibling presentation layers', () {
    final violations = graph.siblingLayerImportViolations(
      forbiddenLayers: const {'presentation'},
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('features import sibling contracts through public entries', () {
    final violations = graph.siblingLayerImportViolations(
      forbiddenLayers: const {'application', 'data', 'domain'},
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
    'feature public entries expose no data or presentation implementations',
    () {
      final violations = <String>[];
      for (final entry in [
        File('lib/src/features/ai_settings/ai_settings.dart'),
        File('lib/src/features/chat/chat.dart'),
        File('lib/src/features/papers/papers.dart'),
      ]) {
        for (final exported in graph.exportClosure(entry).skip(1)) {
          final layer = graph.featureLayer(exported);
          if (layer == 'data' || layer == 'presentation') {
            violations.add(
              '${graph.relativePath(entry)} -> ${graph.relativePath(exported)}',
            );
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test('root public entry does not re-export feature implementations', () {
    final entry = File('lib/spark.dart');
    final violations = graph
        .exportClosure(entry)
        .skip(1)
        .where((exported) {
          final layer = graph.featureLayer(exported);
          return layer == 'data' || layer == 'presentation';
        })
        .map(
          (exported) =>
              '${graph.relativePath(entry)} -> ${graph.relativePath(exported)}',
        )
        .toList(growable: false);

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('production code contains no anonymous broad catch', () {
    final patterns = <String, RegExp>{
      'anonymous catch variable': RegExp(r'catch\s*\(\s*_{1,}\s*(?:,|\))'),
      'unbound broad on-clause': RegExp(r'on\s+(?:Object|Exception)\s*\{'),
    };
    final violations = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final entry in patterns.entries) {
        for (final match in entry.value.allMatches(source)) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          violations.add('${file.path}:$line: ${entry.key}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('production code sends runtime logs through SparkDiagnostics', () {
    final allowedLogWriter = File(
      'lib/src/core/diagnostics/runtime_diagnostics.dart',
    ).absolute.path.replaceAll('\\', '/');
    final patterns = <String, RegExp>{
      'dart:developer import': RegExp(r'''['"]dart:developer['"]'''),
      'developer.log call': RegExp(r'\bdeveloper\s*\.\s*log\s*\('),
      'debugPrint call': RegExp(r'\bdebugPrint\s*\('),
      'print call': RegExp(r'\bprint\s*\('),
    };
    final violations = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final normalizedPath = file.absolute.path.replaceAll('\\', '/');
      if (normalizedPath == allowedLogWriter) continue;
      final source = file.readAsStringSync();
      for (final entry in patterns.entries) {
        for (final match in entry.value.allMatches(source)) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          violations.add('${file.path}:$line: ${entry.key}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
    'paper reader presentation leaves keyword cache rules to application',
    () {
      final source = File(
        'lib/src/features/papers/presentation/widgets/paper_reader_view.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('keywordRepository?.load(')));
      expect(source, isNot(contains('isPaperKeywordCacheFresh(')));
    },
  );
}
