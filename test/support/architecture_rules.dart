import 'dart:io';

import 'architecture_source_graph.dart';

extension ArchitectureRules on ArchitectureSourceGraph {
  static const Set<String> defaultDomainDartLibraries = {
    'dart:async',
    'dart:collection',
    'dart:math',
  };

  List<String> sameFeatureLayerViolations() {
    const forbiddenTargets = <String, Set<String>>{
      'domain': {'application', 'data', 'presentation'},
      'application': {'data', 'presentation'},
      'data': {'application', 'presentation'},
      'presentation': {'data'},
    };
    final violations = <String>{};

    for (final source in sourceFiles) {
      final sourceFeature = featureName(source);
      final sourceLayer = featureLayer(source);
      final forbiddenLayers = forbiddenTargets[sourceLayer];
      if (sourceFeature == null || forbiddenLayers == null) continue;

      for (final directive in directives(source)) {
        for (final target in directiveClosure(source, directive)) {
          if (featureName(target) != sourceFeature) continue;
          final targetLayer = featureLayer(target);
          if (targetLayer != null && forbiddenLayers.contains(targetLayer)) {
            violations.add(
              '${relativePath(source)} -> $directive -> '
              '${relativePath(target)}',
            );
          }
        }
      }
    }

    return violations.toList(growable: false)..sort();
  }

  List<String> domainDependencyViolations({
    Set<String> allowedDartLibraries = defaultDomainDartLibraries,
    Set<String> allowedExternalPackages = const {},
  }) {
    final violations = <String>{};

    for (final source in sourceFiles.where(
      (candidate) => featureLayer(candidate) == 'domain',
    )) {
      for (final directive in directives(source)) {
        if (directive.startsWith('dart:')) {
          if (!allowedDartLibraries.contains(directive)) {
            violations.add(
              '${relativePath(source)} -> $directive '
              '(Dart library is not domain-safe)',
            );
          }
          continue;
        }

        if (directive.startsWith('package:')) {
          final importedPackage = _packageFrom(directive);
          if (importedPackage != packageName &&
              !allowedExternalPackages.contains(importedPackage)) {
            violations.add(
              '${relativePath(source)} -> $directive '
              '(external package is not explicitly domain-safe)',
            );
            continue;
          }
        }

        final resolved = resolve(source, directive);
        if (resolved == null) continue;
        for (final target in exportClosure(resolved)) {
          final targetFeature = featureName(target);
          if (targetFeature != null &&
              isFeaturePublicEntry(target, targetFeature)) {
            continue;
          }
          if (featureLayer(target) != 'domain') {
            violations.add(
              '${relativePath(source)} -> $directive -> '
              '${relativePath(target)} '
              '(domain may only depend on domain source)',
            );
          }
        }
      }
    }

    return violations.toList(growable: false)..sort();
  }

  List<String> importCycles() {
    final sourceFilesByIdentity = {
      for (final file in sourceFiles) identity(file): file,
    };
    final adjacency = <String, List<String>>{};
    for (final source in sourceFiles) {
      final sourceId = identity(source);
      final targets = <String>{};
      for (final directive in directives(source)) {
        final target = resolve(source, directive);
        if (target == null) continue;
        final targetId = identity(target);
        if (sourceFilesByIdentity.containsKey(targetId)) targets.add(targetId);
      }
      adjacency[sourceId] = targets.toList(growable: false)..sort();
    }

    final components = _stronglyConnectedComponents(adjacency);
    final cycles = <String>[];
    for (final component in components) {
      if (component.length == 1) {
        final node = component.single;
        if (!(adjacency[node] ?? const <String>[]).contains(node)) continue;
      }
      final cycle = _findCycle(
        component: component,
        adjacency: adjacency,
        filesByIdentity: sourceFilesByIdentity,
      );
      if (cycle != null) {
        cycles.add(
          cycle
              .map((node) => relativePath(sourceFilesByIdentity[node]!))
              .join(' -> '),
        );
      }
    }

    return cycles..sort();
  }

  List<String> coreWidgetReuseViolations({int minimumFeatureCount = 2}) {
    final filesByIdentity = {
      for (final file in sourceFiles) identity(file): file,
    };
    final importersByTarget = <String, Set<String>>{};
    for (final source in sourceFiles) {
      final usageDirectives = [
        ...imports(source),
        if (_isCoreSource(source)) ...exports(source),
      ];
      for (final directive in usageDirectives) {
        final target = resolve(source, directive);
        if (target == null) continue;
        final targetId = identity(target);
        if (!filesByIdentity.containsKey(targetId)) continue;
        importersByTarget.putIfAbsent(targetId, () => <String>{}).add(
              identity(source),
            );
      }
    }

    final violations = <String>[];
    for (final candidate in sourceFiles.where(_isCoreWidget)) {
      final features = <String>{};
      final visited = <String>{identity(candidate)};
      final pending = <String>[identity(candidate)];

      while (pending.isNotEmpty) {
        final targetId = pending.removeLast();
        for (final importerId in importersByTarget[targetId] ?? const {}) {
          if (!visited.add(importerId)) continue;
          final importer = filesByIdentity[importerId]!;
          final feature = featureName(importer);
          if (feature != null) {
            features.add(feature);
          } else if (_isCoreSource(importer)) {
            pending.add(importerId);
          }
        }
      }

      if (features.length < minimumFeatureCount) {
        final sortedFeatures = features.toList(growable: false)..sort();
        violations.add(
          '${relativePath(candidate)} -> features: '
          '${sortedFeatures.isEmpty ? 'none' : sortedFeatures.join(', ')} '
          '(requires at least $minimumFeatureCount)',
        );
      }
    }

    return violations..sort();
  }

  List<String> siblingLayerImportViolations({
    required Set<String> forbiddenLayers,
  }) {
    final violations = <String>{};
    for (final source in sourceFiles) {
      final sourceFeature = featureName(source);
      if (sourceFeature == null) continue;
      for (final directive in directives(source)) {
        final directImport = resolve(source, directive);
        final directTargetFeature =
            directImport == null ? null : featureName(directImport);
        if (directTargetFeature != null &&
            directTargetFeature != sourceFeature &&
            isFeaturePublicEntry(directImport!, directTargetFeature)) {
          continue;
        }
        for (final target in directiveClosure(source, directive)) {
          final targetFeature = featureName(target);
          if (targetFeature == null || targetFeature == sourceFeature) continue;
          if (pathSegments(target).any(forbiddenLayers.contains)) {
            violations.add(
              '${relativePath(source)} -> $directive -> '
              '${relativePath(target)}',
            );
          }
        }
      }
    }
    return violations.toList(growable: false)..sort();
  }

  List<String> importsMatching(
    Iterable<File> files,
    bool Function(File imported) predicate,
  ) {
    final violations = <String>{};
    for (final source in files) {
      for (final directive in directives(source)) {
        for (final target in directiveClosure(source, directive)) {
          if (predicate(target)) {
            violations.add(
              '${relativePath(source)} -> $directive -> '
              '${relativePath(target)}',
            );
          }
        }
      }
    }
    return violations.toList(growable: false)..sort();
  }

  bool _isCoreWidget(File file) {
    final path = relativePath(file);
    return path.startsWith('lib/src/core/widgets/');
  }

  bool _isCoreSource(File file) {
    final segments = pathSegments(file);
    final srcIndex = segments.indexOf('src');
    return srcIndex >= 0 &&
        srcIndex + 1 < segments.length &&
        segments[srcIndex + 1] == 'core';
  }

  List<Set<String>> _stronglyConnectedComponents(
    Map<String, List<String>> adjacency,
  ) {
    var nextIndex = 0;
    final indices = <String, int>{};
    final lowLinks = <String, int>{};
    final stack = <String>[];
    final onStack = <String>{};
    final components = <Set<String>>[];

    void connect(String node) {
      indices[node] = nextIndex;
      lowLinks[node] = nextIndex;
      nextIndex++;
      stack.add(node);
      onStack.add(node);

      for (final target in adjacency[node] ?? const <String>[]) {
        if (!indices.containsKey(target)) {
          connect(target);
          lowLinks[node] = _min(lowLinks[node]!, lowLinks[target]!);
        } else if (onStack.contains(target)) {
          lowLinks[node] = _min(lowLinks[node]!, indices[target]!);
        }
      }

      if (lowLinks[node] != indices[node]) return;
      final component = <String>{};
      String member;
      do {
        member = stack.removeLast();
        onStack.remove(member);
        component.add(member);
      } while (member != node);
      components.add(component);
    }

    for (final node in adjacency.keys.toList(growable: false)..sort()) {
      if (!indices.containsKey(node)) connect(node);
    }
    return components;
  }

  List<String>? _findCycle({
    required Set<String> component,
    required Map<String, List<String>> adjacency,
    required Map<String, File> filesByIdentity,
  }) {
    final starts = component.toList(growable: false)
      ..sort((left, right) => relativePath(filesByIdentity[left]!)
          .compareTo(relativePath(filesByIdentity[right]!)));

    for (final start in starts) {
      final path = <String>[start];
      final visiting = <String>{start};

      List<String>? search(String node) {
        final targets = (adjacency[node] ?? const <String>[])
            .where(component.contains)
            .toList(growable: false)
          ..sort((left, right) => relativePath(filesByIdentity[left]!)
              .compareTo(relativePath(filesByIdentity[right]!)));
        for (final target in targets) {
          if (target == start) return [...path, start];
          if (!visiting.add(target)) continue;
          path.add(target);
          final cycle = search(target);
          if (cycle != null) return cycle;
          path.removeLast();
          visiting.remove(target);
        }
        return null;
      }

      final cycle = search(start);
      if (cycle != null) return cycle;
    }
    return null;
  }
}

String _packageFrom(String directive) {
  final withoutPrefix = directive.substring('package:'.length);
  final slash = withoutPrefix.indexOf('/');
  return slash < 0 ? withoutPrefix : withoutPrefix.substring(0, slash);
}

int _min(int left, int right) => left < right ? left : right;
