import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';

void main() {
  test('Android leaves keyboard movement to the Flutter chat surface', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android:windowSoftInputMode="adjustNothing"'),
    );
    expect(
      manifest,
      isNot(anyOf(contains('adjustPan'), contains('adjustResize'))),
    );
  });

  testWidgets('Android moves only the chat body above the keyboard', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(const SparkApp(showSplash: false));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
      await tester.pumpAndSettle();

      final appBar = find.byType(AppBar);
      final conversation = find.byKey(
        const ValueKey('global-paper-ai-chat'),
      );
      final composer = find.byKey(
        const ValueKey('paper-ai-composer-surface'),
      );
      final initialAppBarRect = tester.getRect(appBar);
      final initialConversationRect = tester.getRect(conversation);
      final initialComposerRect = tester.getRect(composer);
      final input = find.byKey(const ValueKey('paper-ai-input'));
      await tester.tap(input);
      await tester.pump();
      final editable = tester.widget<EditableText>(
        find.descendant(of: input, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);

      final layoutLogs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) layoutLogs.add(message);
      };
      debugPrintLayouts = true;
      try {
        for (final logicalInset in _imeFrames) {
          tester.view.viewInsets = FakeViewPadding(
            bottom: logicalInset * tester.view.devicePixelRatio,
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(appBar), initialAppBarRect);
          expect(
            tester.getRect(conversation),
            initialConversationRect.shift(Offset(0, -logicalInset)),
          );
          expect(
            tester.getRect(composer),
            initialComposerRect.shift(Offset(0, -logicalInset)),
          );
        }
      } finally {
        debugPrintLayouts = false;
        debugPrint = previousDebugPrint;
      }

      expect(tester.getRect(appBar), initialAppBarRect);
      expect(
        tester.getRect(conversation),
        initialConversationRect.shift(const Offset(0, -320)),
      );
      expect(
        tester.getRect(composer),
        initialComposerRect.shift(const Offset(0, -320)),
      );
      expect(MediaQuery.viewInsetsOf(tester.element(composer)).bottom, 0);
      printOnFailure('Chat IME layout count: ${layoutLogs.length}');
      expect(
        layoutLogs.length,
        lessThanOrEqualTo(450),
        reason: '键盘过渡应更新对话 body 的图层变换，不能逐帧重排消息树。',
      );

      editable.focusNode.unfocus();
      await tester.pump();
      await tester.tap(input);
      await tester.pump();
      expect(editable.focusNode.hasFocus, isTrue);
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

const _imeFrames = <double>[40, 80, 120, 160, 200, 240, 280, 320];
