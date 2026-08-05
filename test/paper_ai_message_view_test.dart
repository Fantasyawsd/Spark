import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('copying an assistant message excludes reasoning COT',
      (tester) async {
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      wrap(
        PaperAiMessageView(
          message: const ChatMessage(
            fromUser: false,
            reasoningContent: 'internal chain of thought',
            content: '公开回答',
          ),
          streaming: false,
          searching: false,
        ),
      ),
    );

    await tester.tap(find.byTooltip('复制'));
    await tester.pump();

    expect(copiedText, '公开回答');
    expect(copiedText, isNot(contains('internal chain of thought')));
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

  testWidgets('message actions keep only the requested mobile controls',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            PaperAiMessageView(
              message: const ChatMessage(fromUser: true, content: '用户问题'),
              streaming: false,
              searching: false,
              isLatest: true,
              onEdit: () {},
            ),
            PaperAiMessageView(
              message: const ChatMessage(fromUser: false, content: '旧回答'),
              streaming: false,
              searching: false,
              isLatest: false,
              onRetry: () {},
              onDelete: () {},
            ),
            PaperAiMessageView(
              message: const ChatMessage(fromUser: false, content: '最新回答'),
              streaming: false,
              searching: false,
              isLatest: true,
              onRetry: () {},
              onDelete: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byTooltip('朗读'), findsNothing);
    expect(find.byTooltip('翻译'), findsNothing);
    expect(find.byTooltip('复制'), findsNWidgets(3));
    expect(find.byTooltip('修改'), findsOneWidget);
    expect(find.byTooltip('重新生成'), findsOneWidget);
    expect(find.byTooltip('更多'), findsNWidgets(2));
    expect(find.text('Fork 会话'), findsNothing);
  });
}
