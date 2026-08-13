import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
