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
}
