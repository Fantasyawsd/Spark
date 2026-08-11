import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_chat_screen.dart';

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

  testWidgets(
      'Android keeps the chat viewport stable while moving the composer', (
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
          expect(tester.getRect(conversation), initialConversationRect);
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
      expect(tester.getRect(conversation), initialConversationRect);
      expect(
        tester.getRect(composer),
        initialComposerRect.shift(const Offset(0, -320)),
      );
      expect(MediaQuery.viewInsetsOf(tester.element(composer)).bottom, 0);
      printOnFailure('Chat IME layout count: ${layoutLogs.length}');
      expect(
        layoutLogs.length,
        lessThanOrEqualTo(360),
        reason: '键盘过渡只应更新输入区位置，不能逐帧变换或重排消息树。',
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

  testWidgets(
      'Android keeps the latest messages anchored to the moving composer', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.binding.setSurfaceSize(const Size(378, 810));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);

      final messages = List<ChatMessage>.generate(
        20,
        (index) => ChatMessage(
          fromUser: index.isEven,
          content: '第 $index 条消息：用于验证长对话在键盘过渡期间的底部锚定。',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PaperAiChatScreen(
            chatContext: const ChatContext(
              id: 'android-ime-anchor',
              title: '键盘锚定测试',
              systemPrompt: '回答问题。',
            ),
            aiService: const _FakeChatAiService(),
            sessionRepository: _FakeChatSessionRepository(messages),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final conversation = find.byKey(
        const ValueKey('global-paper-ai-chat'),
      );
      final initialConversationRect = tester.getRect(conversation);
      final controller = tester.widget<ListView>(conversation).controller!;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      final initialMaxScrollExtent = controller.position.maxScrollExtent;
      final initialOffset = controller.offset;

      await tester.tap(find.byKey(const ValueKey('paper-ai-input')));
      await tester.pump();
      for (final logicalInset in _imeFrames) {
        tester.view.viewInsets = FakeViewPadding(
          bottom: logicalInset * tester.view.devicePixelRatio,
        );
        await tester.pump(const Duration(milliseconds: 16));

        expect(tester.getRect(conversation), initialConversationRect);
        expect(
          controller.position.maxScrollExtent,
          closeTo(initialMaxScrollExtent + logicalInset, 0.01),
        );
        expect(
          controller.offset,
          closeTo(initialOffset + logicalInset, 0.01),
        );
      }
      for (final logicalInset in <double>[280, 240, 200, 160, 120, 80, 40, 0]) {
        tester.view.viewInsets = FakeViewPadding(
          bottom: logicalInset * tester.view.devicePixelRatio,
        );
        await tester.pump(const Duration(milliseconds: 16));

        expect(tester.getRect(conversation), initialConversationRect);
        expect(
          controller.position.maxScrollExtent,
          closeTo(initialMaxScrollExtent + logicalInset, 0.01),
        );
        expect(
          controller.offset,
          closeTo(initialOffset + logicalInset, 0.01),
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

const _imeFrames = <double>[40, 80, 120, 160, 200, 240, 280, 320];

class _FakeChatAiService implements ChatAiService {
  const _FakeChatAiService();

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '回答';
}

class _FakeChatSessionRepository implements ChatSessionRepository {
  const _FakeChatSessionRepository(this.messages);

  final List<ChatMessage> messages;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<List<ChatMessage>> load(String contextId) async => messages;

  @override
  Future<List<ChatSessionSummary>> listSessions() async => const [];

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}
