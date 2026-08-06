import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/features/papers/application/paper_chat_context.dart';
import 'package:paperflow/src/features/papers/presentation/widgets/paper_ai_content.dart';

void main() {
  testWidgets('AI answer exposes a collapsible reasoning chain',
      (tester) async {
    Uri? openedSource;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PaperAiContent(
                chatContext: PaperChatContext.fromPaper(demoPapers.first),
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
                onOpenSource: (uri) async {
                  openedSource = uri;
                  return true;
                },
                searching: false,
                requestStatus: PaperAiRequestStatus.completed,
                canRetryRequestError: false,
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

    // 来源默认折叠，展开后才能看到并可点击来源行。
    await tester.tap(find.byKey(const ValueKey('paper-ai-sources-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paper-ai-source-1')));
    expect(openedSource, Uri.parse('https://example.test/paper'));

    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('先检查方法，再核对实验。'), findsOneWidget);
    expect(find.text('结论'), findsOneWidget);
  });
  testWidgets('sources are collapsed by default and expand on demand',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PaperAiContent(
                chatContext: PaperChatContext.fromPaper(demoPapers.first),
                messages: const [
                  PaperAiMessage(
                    fromUser: false,
                    content: '**结论**',
                    sources: [
                      PaperAiSource(
                        title: '来源一',
                        url: 'https://example.test/one',
                      ),
                      PaperAiSource(
                        title: '来源二',
                        url: 'https://example.test/two',
                      ),
                      PaperAiSource(
                        title: '来源三',
                        url: 'https://example.test/three',
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
                requestStatus: PaperAiRequestStatus.completed,
                canRetryRequestError: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('paper-ai-sources')), findsOneWidget);
    expect(find.text('3 个'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-source-1')), findsNothing);
    expect(find.byKey(const ValueKey('paper-ai-source-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('paper-ai-sources-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paper-ai-source-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-source-3')), findsOneWidget);
    expect(find.textContaining('另有'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing a stream auto-collapses visible reasoning',
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
                    chatContext: PaperChatContext.fromPaper(demoPapers.first),
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
                    requestStatus: sending
                        ? PaperAiRequestStatus.sending
                        : PaperAiRequestStatus.completed,
                    canRetryRequestError: false,
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

    expect(
        find.byKey(const ValueKey('paper-ai-reasoning-panel')), findsOneWidget);
    expect(find.textContaining('比较目标函数'), findsNothing);
  });

  testWidgets(
      'AI answer does not add a generating label to the assistant header',
      (tester) async {
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
                    chatContext: PaperChatContext.fromPaper(demoPapers.first),
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
                    requestStatus: PaperAiRequestStatus.sending,
                    canRetryRequestError: false,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('正在搜索'), findsNothing);
    expect(find.text('正在生成'), findsNothing);

    update(() => searching = false);
    await tester.pump();
    expect(find.text('正在搜索'), findsNothing);
    expect(find.text('正在生成'), findsNothing);
  });

  testWidgets('cancelled AI request shows a neutral regenerate action',
      (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PaperAiContent(
                chatContext: PaperChatContext.fromPaper(demoPapers.first),
                messages: const [
                  PaperAiMessage(fromUser: true, content: '分析论文'),
                  PaperAiMessage(fromUser: false, content: '部分回答'),
                ],
                loading: false,
                sending: false,
                error: null,
                onPrompt: (_) {},
                onRetry: () => retries++,
                onCancel: () {},
                searching: false,
                requestStatus: PaperAiRequestStatus.cancelled,
                canRetryRequestError: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('paper-ai-cancelled')), findsOneWidget);
    expect(find.text('已停止生成'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-regenerate')), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);

    await tester.tap(find.byKey(const ValueKey('paper-ai-regenerate')));
    expect(retries, 1);
  });

  testWidgets('persistence error hides cancelled state and invalid retry',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PaperAiContent(
                chatContext: PaperChatContext.fromPaper(demoPapers.first),
                messages: const [],
                loading: false,
                sending: false,
                error: '无法清空 AI 对话记录。',
                onPrompt: (_) {},
                onRetry: () {},
                onCancel: () {},
                searching: false,
                requestStatus: PaperAiRequestStatus.cancelled,
                canRetryRequestError: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('paper-ai-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-cancelled')), findsNothing);
    expect(find.byKey(const ValueKey('paper-ai-retry')), findsNothing);
  });

  testWidgets('request error exposes the AI retry action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PaperAiContent(
                chatContext: PaperChatContext.fromPaper(demoPapers.first),
                messages: const [
                  PaperAiMessage(fromUser: true, content: '问题'),
                ],
                loading: false,
                sending: false,
                error: '网络失败',
                onPrompt: (_) {},
                onRetry: () => retries++,
                onCancel: () {},
                searching: false,
                requestStatus: PaperAiRequestStatus.failed,
                canRetryRequestError: true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('paper-ai-retry')));
    expect(retries, 1);
  });
}
