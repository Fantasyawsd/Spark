import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/papers/presentation/widgets/paper_message_composer.dart';

void main() {
  testWidgets('comment composer shows fixed sending progress', (tester) async {
    final controller = TextEditingController(text: '正在发送');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperMessageComposer(
            controller: controller,
            aiMode: false,
            enabled: false,
            sending: true,
            onChanged: (_) {},
            onSend: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('paper-comment-sending')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
  });
}
