import 'dart:io';

/// Parsed Dart source graph used by architecture tests.
///
/// An arbitrary package root can be supplied so rules are verifiable against
/// isolated fixtures instead of only the repository's current source tree.
class ArchitectureSourceGraph {
  ArchitectureSourceGraph({
    required Directory sourceRoot,
    required Directory packageRoot,
    this.packageName = 'spark',
  })  : sourceRoot = sourceRoot.absolute,
        packageRoot = packageRoot.absolute {
    sourceFiles = this
        .sourceRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.absolute)
        .toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
  }

  final Directory sourceRoot;
  final Directory packageRoot;
  final String packageName;
  late final List<File> sourceFiles;

  List<String> directives(File file) => _sourceDirectives(file)
      .expand((directive) => directive.uris)
      .toList(growable: false);

  List<String> imports(File file) => _sourceDirectives(file)
      .where((directive) => directive.kind == 'import')
      .expand((directive) => directive.uris)
      .toList(growable: false);

  List<String> exports(File file) => _sourceDirectives(file)
      .where((directive) => directive.kind == 'export')
      .expand((directive) => directive.uris)
      .toList(growable: false);

  List<File> directiveClosure(File source, String directive) {
    final target = resolve(source, directive);
    return target == null ? const [] : exportClosure(target);
  }

  List<File> exportClosure(File entry) {
    final files = <File>[];
    final visited = <String>{};

    void visit(File file) {
      final absolute = file.absolute;
      if (!visited.add(identity(absolute)) || !absolute.existsSync()) return;
      files.add(absolute);
      for (final directive in exports(absolute)) {
        final exported = resolve(absolute, directive);
        if (exported != null) visit(exported);
      }
    }

    visit(entry);
    return files;
  }

  File? resolve(File source, String directive) {
    if (directive.startsWith('dart:')) return null;
    final ownPackagePrefix = 'package:$packageName/';
    if (directive.startsWith(ownPackagePrefix)) {
      final path = directive.substring(ownPackagePrefix.length);
      return File.fromUri(packageRoot.uri.resolve('lib/$path')).absolute;
    }
    if (directive.startsWith('package:')) return null;
    return File.fromUri(source.absolute.uri.resolve(directive)).absolute;
  }

  List<String> pathSegments(File file) => relativePath(file)
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  String relativePath(File file) {
    final root = _normalizePath(packageRoot.path);
    final path = _normalizePath(file.absolute.path);
    final prefix = '$root/';
    return path.startsWith(prefix) ? path.substring(prefix.length) : path;
  }

  String identity(File file) =>
      _normalizePath(file.absolute.path).toLowerCase();

  String? featureName(File file) {
    final segments = pathSegments(file);
    final featuresIndex = segments.lastIndexOf('features');
    if (featuresIndex < 0 || featuresIndex + 1 >= segments.length) return null;
    return segments[featuresIndex + 1];
  }

  String? featureLayer(File file) {
    final segments = pathSegments(file);
    final featuresIndex = segments.lastIndexOf('features');
    if (featuresIndex < 0 || featuresIndex + 2 >= segments.length) return null;
    final layer = segments[featuresIndex + 2];
    return const {'application', 'data', 'domain', 'presentation'}
            .contains(layer)
        ? layer
        : null;
  }

  bool isFeaturePublicEntry(File file, String feature) {
    final segments = pathSegments(file);
    final featuresIndex = segments.lastIndexOf('features');
    return featuresIndex >= 0 &&
        featuresIndex + 2 == segments.length - 1 &&
        segments[featuresIndex + 1] == feature &&
        segments.last == '$feature.dart';
  }

  List<_SourceDirective> _sourceDirectives(File file) {
    final contents = file.readAsStringSync();
    return _directiveStatementPattern.allMatches(contents).map((match) {
      final uris = _uriPattern
          .allMatches(match.group(2)!)
          .map((uriMatch) => uriMatch.group(1)!)
          .toList(growable: false);
      return _SourceDirective(kind: match.group(1)!, uris: uris);
    }).toList(growable: false);
  }
}

class _SourceDirective {
  const _SourceDirective({required this.kind, required this.uris});

  final String kind;
  final List<String> uris;
}

final _directiveStatementPattern = RegExp(
  r'''\b(import|export)\s+([^;]+);''',
  multiLine: true,
);

final _uriPattern = RegExp(r'''['"]([^'"]+)['"]''');

String _normalizePath(String path) => path.replaceAll('\\', '/');
