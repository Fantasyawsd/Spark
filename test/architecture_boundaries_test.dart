import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sourceFiles = Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);

  test('feature data layers do not depend on application layers', () {
    final violations = _importsMatching(
      sourceFiles.where((file) => _segments(file).contains('data')),
      (imported) => _segments(imported).contains('application'),
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('feature domain layers remain framework and infrastructure free', () {
    final violations = <String>[];
    for (final file in sourceFiles.where(
      (candidate) => _segments(candidate).contains('domain'),
    )) {
      for (final import in _directives(file)) {
        if (import.startsWith('package:flutter') ||
            import.startsWith('package:http') ||
            import == 'dart:io') {
          violations.add('${file.path} -> $import');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('core does not depend on business features', () {
    final coreFiles = sourceFiles.where(
      (file) => _segments(file).contains('core'),
    );
    final violations = _importsMatching(
      coreFiles,
      (imported) => _segments(imported).contains('features'),
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('features do not deep import sibling presentation layers', () {
    final violations = _siblingLayerImports(
      sourceFiles,
      forbiddenLayers: const {'presentation'},
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('features import sibling contracts through public entries', () {
    final violations = _siblingLayerImports(
      sourceFiles,
      forbiddenLayers: const {'application', 'data', 'domain'},
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('feature public entries expose no data or presentation implementations',
      () {
    final violations = <String>[];
    for (final entry in [
      File('lib/src/features/ai_settings/ai_settings.dart'),
      File('lib/src/features/chat/chat.dart'),
      File('lib/src/features/papers/papers.dart'),
    ]) {
      for (final exported in _exportClosure(entry).skip(1)) {
        final layer = _featureLayer(exported);
        if (layer == 'data' || layer == 'presentation') {
          violations.add('${entry.path} -> ${exported.path}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('root public entry does not re-export feature implementations', () {
    final entry = File('lib/spark.dart');
    final violations = _exportClosure(entry)
        .skip(1)
        .where((exported) {
          final layer = _featureLayer(exported);
          return layer == 'data' || layer == 'presentation';
        })
        .map((exported) => '${entry.path} -> ${exported.path}')
        .toList(growable: false);

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

List<String> _siblingLayerImports(
  Iterable<File> sourceFiles, {
  required Set<String> forbiddenLayers,
}) {
  final violations = <String>[];
  for (final file in sourceFiles) {
    final sourceFeature = _featureName(file);
    if (sourceFeature == null) continue;
    for (final directive in _directives(file)) {
      final directImport = _resolve(file, directive);
      final directTargetFeature =
          directImport == null ? null : _featureName(directImport);
      if (directTargetFeature != null &&
          directTargetFeature != sourceFeature &&
          _isFeaturePublicEntry(directImport!, directTargetFeature)) {
        continue;
      }
      for (final imported in _directiveClosure(file, directive)) {
        final targetFeature = _featureName(imported);
        if (targetFeature == null || targetFeature == sourceFeature) continue;
        final targetSegments = _segments(imported);
        if (targetSegments.any(forbiddenLayers.contains)) {
          violations.add('${file.path} -> $directive -> ${imported.path}');
        }
      }
    }
  }
  return violations;
}

bool _isFeaturePublicEntry(File file, String feature) {
  final segments = _segments(file);
  final featuresIndex = segments.lastIndexOf('features');
  return featuresIndex >= 0 &&
      featuresIndex + 2 == segments.length - 1 &&
      segments[featuresIndex + 1] == feature &&
      segments.last == '$feature.dart';
}

final _directivePattern = RegExp(
  r'''(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

final _exportPattern = RegExp(
  r'''export\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

List<String> _directives(File file) => _directivePattern
    .allMatches(file.readAsStringSync())
    .map((match) => match.group(1)!)
    .toList(growable: false);

List<String> _exports(File file) => _exportPattern
    .allMatches(file.readAsStringSync())
    .map((match) => match.group(1)!)
    .toList(growable: false);

List<String> _importsMatching(
  Iterable<File> files,
  bool Function(File imported) predicate,
) {
  final violations = <String>[];
  for (final file in files) {
    for (final directive in _directives(file)) {
      for (final imported in _directiveClosure(file, directive)) {
        if (predicate(imported)) {
          violations.add('${file.path} -> $directive -> ${imported.path}');
        }
      }
    }
  }
  return violations;
}

List<File> _directiveClosure(File source, String directive) {
  final imported = _resolve(source, directive);
  return imported == null ? const [] : _exportClosure(imported);
}

List<File> _exportClosure(File entry) {
  final files = <File>[];
  final visited = <String>{};

  void visit(File file) {
    final absolute = file.absolute;
    final identity = absolute.path.toLowerCase();
    if (!visited.add(identity) || !absolute.existsSync()) return;
    files.add(absolute);
    for (final directive in _exports(absolute)) {
      final exported = _resolve(absolute, directive);
      if (exported != null) visit(exported);
    }
  }

  visit(entry);
  return files;
}

File? _resolve(File source, String directive) {
  if (directive.startsWith('dart:')) return null;
  if (directive.startsWith('package:spark/')) {
    return File('lib/${directive.substring('package:spark/'.length)}');
  }
  if (directive.startsWith('package:')) return null;
  return File.fromUri(source.absolute.uri.resolve(directive));
}

List<String> _segments(File file) => file.path
    .replaceAll('\\', '/')
    .split('/')
    .where((segment) => segment.isNotEmpty)
    .toList(growable: false);

String? _featureName(File file) {
  final segments = _segments(file);
  final featuresIndex = segments.lastIndexOf('features');
  if (featuresIndex < 0 || featuresIndex + 1 >= segments.length) return null;
  return segments[featuresIndex + 1];
}

String? _featureLayer(File file) {
  final segments = _segments(file);
  final featuresIndex = segments.lastIndexOf('features');
  if (featuresIndex < 0 || featuresIndex + 2 >= segments.length) return null;
  return segments[featuresIndex + 2];
}
