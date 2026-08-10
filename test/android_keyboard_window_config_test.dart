import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/app/spark_bottom_nav.dart';

void main() {
  test('Android delegates keyboard avoidance to whole-window panning', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android:windowSoftInputMode="adjustPan"'),
    );
    expect(
      manifest,
      isNot(contains('android:windowSoftInputMode="adjustResize"')),
    );
  });

  testWidgets('Android Flutter layout stays static while the window pans', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(const SparkApp(showSplash: false));
      await tester.pump();
      final bottomNav = find.byType(SparkBottomNav);
      final initialRect = tester.getRect(bottomNav);

      tester.view.viewInsets = FakeViewPadding(
        bottom: 320 * tester.view.devicePixelRatio,
      );
      await tester.pump();

      final shellContext = tester.element(find.byType(SparkShell));
      expect(MediaQuery.viewInsetsOf(shellContext).bottom, 0);
      expect(tester.getRect(bottomNav), initialRect);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('non-Android platforms keep Flutter keyboard insets', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(const SparkApp(showSplash: false));
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding(
        bottom: 320 * tester.view.devicePixelRatio,
      );
      await tester.pump();

      final shellContext = tester.element(find.byType(SparkShell));
      expect(MediaQuery.viewInsetsOf(shellContext).bottom, 320);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
