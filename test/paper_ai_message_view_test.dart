import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/core/widgets/paperflow_markdown.dart';
import 'package:paperflow/src/features/chat/domain/chat_message.dart';
import 'package:paperflow/src/features/chat/presentation/widgets/paper_ai_message_view.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  PaperMarkdown markdownOf(WidgetTester tester) {
    return tester.widget<PaperMarkdown>(find.byType(PaperMarkdown).first);
  }

  testWidgets('assistant content stays non-selectable while streaming',
      (tester) async {
    await tester.pumpWidget(
      wrap(PaperAiMessageView(
        message: const ChatMessage(fromUser: false, content: '正在生成…'),
        streaming: true,
        searching: false,
      )),
    );

    expect(markdownOf(tester).selectable, isFalse);
  });

  testWidgets('assistant content stays non-selectable after streaming ends',
      (tester) async {
    await tester.pumpWidget(
      wrap(PaperAiMessageView(
        message: const ChatMessage(fromUser: false, content: '回答完成'),
        streaming: false,
        searching: false,
      )),
    );

    expect(markdownOf(tester).selectable, isFalse);
  });

  testWidgets('reasoning panel is not selectable', (tester) async {
    await tester.pumpWidget(
      wrap(PaperAiMessageView(
        message: const ChatMessage(
          fromUser: false,
          content: '',
          reasoningContent: '思考中…',
        ),
        streaming: true,
        searching: false,
      )),
    );

    expect(markdownOf(tester).selectable, isFalse);
  });
}
