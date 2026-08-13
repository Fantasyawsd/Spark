import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart' as public_api;
import 'package:spark/src/app/spark_app.dart' as app_api;
import 'package:spark/src/app/spark_bootstrap.dart';
import 'package:spark/src/core/motion/motion_tokens.dart';

void main() {
  group('SparkBootstrap', () {
    testWidgets('covers the shell until the startup animation completes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SparkBootstrap(
            showSplash: true,
            child: SizedBox(key: ValueKey('application-shell')),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('application-shell')), findsOneWidget);
      expect(find.byKey(const ValueKey('spark-splash')), findsOneWidget);

      await tester.pump(
        MotionTokens.splashDuration + const Duration(milliseconds: 1),
      );

      expect(find.byKey(const ValueKey('application-shell')), findsOneWidget);
      expect(find.byKey(const ValueKey('spark-splash')), findsNothing);
    });

    testWidgets('does not display the overlay when splash is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SparkBootstrap(
            showSplash: false,
            child: SizedBox(key: ValueKey('application-shell')),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('application-shell')), findsOneWidget);
      expect(find.byKey(const ValueKey('spark-splash')), findsNothing);
    });
  });

  test('startup overlay implementation stays outside spark_app.dart', () {
    final appSource = File('lib/src/app/spark_app.dart').readAsStringSync();
    final bootstrapSource = File(
      'lib/src/app/spark_bootstrap.dart',
    ).readAsStringSync();

    expect(appSource, contains("import 'spark_bootstrap.dart';"));
    expect(appSource, isNot(contains('class SparkBootstrap')));
    expect(appSource, isNot(contains("ValueKey('spark-splash')")));
    expect(bootstrapSource, contains('class SparkBootstrap'));
    expect(bootstrapSource, contains("ValueKey('spark-splash')"));
  });

  test('root controller ownership stays in SparkApplicationSession', () {
    final appSource = File('lib/src/app/spark_app.dart').readAsStringSync();
    final shellSource = File('lib/src/app/spark_shell.dart').readAsStringSync();
    final sessionSource = File(
      'lib/src/app/spark_application_session.dart',
    ).readAsStringSync();
    const rootControllerTypes = [
      'PaperController',
      'PaperCommentController',
      'PaperReadingController',
      'ChatConversationCoordinator',
      'ChatSessionController',
      'DeepSeekCredentialController',
      'LocalDataController',
    ];

    expect(
      shellSource,
      contains('late final SparkApplicationSession _session;'),
    );
    for (final type in rootControllerTypes) {
      expect(
        appSource,
        isNot(contains('$type(')),
        reason: '$type must not be constructed by SparkApp',
      );
      expect(
        shellSource,
        isNot(contains('$type(')),
        reason: '$type must not be constructed by SparkShell',
      );
      expect(
        sessionSource,
        contains('$type('),
        reason: '$type must be owned by SparkApplicationSession',
      );
    }
    expect(sessionSource, contains('Future<void> _prepareLocalDataMutation'));
    expect(
        sessionSource, contains('Future<void> _reloadAfterLocalDataMutation'));
  });

  test('navigation shell stays outside spark_app.dart', () {
    final appSource = File('lib/src/app/spark_app.dart').readAsStringSync();
    final shellSource = File('lib/src/app/spark_shell.dart').readAsStringSync();

    expect(appSource, contains("export 'spark_shell.dart' show SparkShell;"));
    expect(appSource, isNot(contains('class SparkShell')));
    expect(appSource, isNot(contains('PaperSearchScreen(')));
    expect(appSource, isNot(contains('PaperDetailScreen(')));
    expect(appSource, isNot(contains('MainAiChatScreen(')));
    expect(appSource.split('\n').length, lessThanOrEqualTo(180));
    expect(shellSource, contains('class SparkShell'));
    expect(shellSource, contains('PaperSearchScreen('));
    expect(shellSource, contains('PaperDetailScreen('));
    expect(shellSource, contains('MainAiChatScreen('));
  });

  test('application constructors expose only complete dependency boundaries',
      () {
    final appSource = File('lib/src/app/spark_app.dart').readAsStringSync();
    final shellSource = File('lib/src/app/spark_shell.dart').readAsStringSync();

    expect(
      _constructorParameterNames(appSource, 'SparkApp'),
      ['key', 'config', 'showSplash', 'dependencies'],
    );
    expect(
      _constructorParameterNames(shellSource, 'SparkShell'),
      ['key', 'dependencies', 'features'],
    );
    expect(
      _constructorParameters(shellSource, 'SparkShell'),
      contains('required this.dependencies'),
    );
  });

  test('preview dependencies are resolved only by the application root', () {
    final shellSource = File('lib/src/app/spark_shell.dart').readAsStringSync();
    final previewCallSites = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in dartFiles) {
      for (final line in file.readAsLinesSync()) {
        if (line.contains('SparkDependencies.preview(') &&
            !line.trimLeft().startsWith('factory ')) {
          previewCallSites.add(file.path.replaceAll('\\', '/'));
        }
      }
    }

    expect(shellSource, isNot(contains('SparkDependencies.preview(')));
    expect(previewCallSites, ['lib/src/app/spark_app.dart']);
  });

  test('SparkShell remains visible through both established imports', () {
    final dependencies = public_api.SparkDependencies.preview();
    final publicShell = public_api.SparkShell(dependencies: dependencies);
    final internalShell = app_api.SparkShell(dependencies: dependencies);

    expect(publicShell, isA<app_api.SparkShell>());
    expect(internalShell, isA<public_api.SparkShell>());
  });
}

String _constructorParameters(String source, String className) {
  final match = RegExp(
    'const $className\\(\\{([\\s\\S]*?)\\n  \\}\\);',
  ).firstMatch(source);
  expect(match, isNotNull,
      reason: '$className must keep a const named constructor');
  return match!.group(1)!;
}

List<String> _constructorParameterNames(String source, String className) {
  final parameters = _constructorParameters(source, className);
  return RegExp(r'(?:super\.|this\.)(\w+)')
      .allMatches(parameters)
      .map((match) => match.group(1)!)
      .toList();
}
