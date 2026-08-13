import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_comment_controller.dart';
import 'support/demo_paper_repository.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_comments_sheet.dart';

void main() {
  testWidgets('half-height comments sheet follows Android IME without relayout',
      (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _openCommentsSheet(tester);
      final input = find.byKey(const ValueKey('paper-comment-input'));
      await tester.tap(input);
      await tester.pump();
      final editable = tester.widget<EditableText>(
        find.descendant(of: input, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);

      final sheet = find.byKey(const ValueKey('paper-comments-sheet'));
      final initialRect = tester.getRect(sheet);
      final layoutLogs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) layoutLogs.add(message);
      };
      debugPrintLayouts = true;
      try {
        await _driveImeTransition(tester);
      } finally {
        debugPrintLayouts = false;
        debugPrint = previousDebugPrint;
      }

      final shiftedRect = tester.getRect(sheet);
      printOnFailure('IME layout count: ${layoutLogs.length}');
      expect(
        shiftedRect.top,
        closeTo(initialRect.top - _keyboardInset, 1),
      );
      expect(
        shiftedRect.bottom,
        closeTo(initialRect.bottom - _keyboardInset, 1),
      );
      expect(shiftedRect.height, closeTo(initialRect.height, 0.1));
      expect(
        layoutLogs.length,
        lessThanOrEqualTo(400),
        reason: '半屏面板应只更新图层变换，不能逐帧重排整张内容树。',
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

  testWidgets('fullscreen comments sheet keeps its top edge during Android IME',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _openCommentsSheet(tester);
      await tester.tap(find.byTooltip('全屏'));
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('paper-comments-sheet'));
      final initialRect = tester.getRect(sheet);
      await _driveImeTransition(tester);
      final resizedRect = tester.getRect(sheet);

      expect(resizedRect.top, closeTo(initialRect.top, 1));
      expect(
        resizedRect.bottom,
        closeTo(initialRect.bottom - _keyboardInset, 1),
      );
      expect(
        resizedRect.height,
        closeTo(initialRect.height - _keyboardInset, 1),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('non-Android comments sheet keeps local inset avoidance', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _openCommentsSheet(tester);
      final sheet = find.byKey(const ValueKey('paper-comments-sheet'));
      final initialRect = tester.getRect(sheet);

      await _driveImeTransition(tester);

      final shiftedRect = tester.getRect(sheet);
      expect(shiftedRect.top, closeTo(initialRect.top - _keyboardInset, 1));
      expect(
          shiftedRect.bottom, closeTo(initialRect.bottom - _keyboardInset, 1));
      expect(shiftedRect.height, closeTo(initialRect.height, 0.1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

const _surfaceSize = Size(378, 810);
const _keyboardInset = 320.0;
const _imeFrames = <double>[40, 80, 120, 160, 200, 240, 280, 320];

Future<void> _openCommentsSheet(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetViewInsets);
  final comments = PaperCommentController();
  addTearDown(comments.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showPaperCommentsSheet(
              context,
              demoPapers.first,
              aiDiscussionBuilder: (
                context, {
                required paper,
                required generatedKeywords,
                required scrollController,
              }) =>
                  const SizedBox.expand(),
              commentController: comments,
            ),
            child: const Text('打开评论'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开评论'));
  await tester.pumpAndSettle();
}

Future<void> _driveImeTransition(WidgetTester tester) async {
  for (final logicalInset in _imeFrames) {
    tester.view.viewInsets = FakeViewPadding(
      bottom: logicalInset * tester.view.devicePixelRatio,
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}
