import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/features/papers/presentation/widgets/paper_ai_content.dart';

void main() {
  testWidgets('AI answer exposes a collapsible reasoning chain',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PaperAiContent(
                paper: demoPapers.first,
                messages: const [
                  PaperAiMessage(fromUser: true, content: '分析论文'),
                  PaperAiMessage(
                    fromUser: false,
                    reasoningContent: '先检查方法，再核对实验。',
                    content: '**结论**',
                    sources: [
                      PaperAiSource(
                        title: '论文主页',
                        url: 'https://example.test/paper',
                      ),
                    ],
                  ),
                ],
                loading: false,
                sending: false,
                error: null,
                onPrompt: (_) {},
                onRetry: () {},
                onCancel: () {},
                searching: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('思考过程'), findsOneWidget);
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('1 个'), findsOneWidget);
    expect(find.text('先检查方法，再核对实验。'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('先检查方法，再核对实验。'), findsOneWidget);
    expect(find.text('结论'), findsOneWidget);
  });

  testWidgets('finishing a stream does not collapse visible reasoning',
      (tester) async {
    var sending = true;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ListView(
                children: [
                  PaperAiContent(
                    paper: demoPapers.first,
                    messages: const [
                      PaperAiMessage(
                        fromUser: false,
                        reasoningContent: r'比较目标函数 $L(\theta)$。',
                        content: '',
                      ),
                    ],
                    loading: false,
                    sending: sending,
                    error: null,
                    onPrompt: (_) {},
                    onRetry: () {},
                    onCancel: () {},
                    searching: false,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('正在思考'), findsOneWidget);
    expect(find.textContaining('比较目标函数'), findsOneWidget);

    update(() => sending = false);
    await tester.pumpAndSettle();

    expect(find.text('思考过程'), findsOneWidget);
    expect(find.textContaining('比较目标函数'), findsOneWidget);
  });

  testWidgets('AI answer exposes search and generation states', (tester) async {
    var searching = true;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ListView(
                children: [
                  PaperAiContent(
                    paper: demoPapers.first,
                    messages: const [
                      PaperAiMessage(fromUser: true, content: '查找最新资料'),
                      PaperAiMessage(fromUser: false, content: '正在整理'),
                    ],
                    loading: false,
                    sending: true,
                    error: null,
                    onPrompt: (_) {},
                    onRetry: () {},
                    onCancel: () {},
                    searching: searching,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('当前上下文'), findsOneWidget);
    expect(find.text('正在搜索'), findsOneWidget);

    update(() => searching = false);
    await tester.pump();
    expect(find.text('正在生成'), findsOneWidget);
  });
}
