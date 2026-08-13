import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/presentation/platform/paper_ai_keyboard_dismissal.dart';

void main() {
  testWidgets('platform dismissal unfocuses and invokes TextInput.hide',
      (tester) async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.textInput, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.textInput, null),
    );

    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(focusNode: focusNode),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    platformPaperAiKeyboardDismissal.dismiss(focusNode);
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(
      calls.where((call) => call.method == 'TextInput.hide'),
      isNotEmpty,
    );
  });
}
