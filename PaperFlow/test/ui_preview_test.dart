import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  testWidgets('paper title copies on tap while body remains selectable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    const title = 'LoRA: Low-Rank Adaptation of Large Language Models';
    await tester.tap(find.byKey(const ValueKey('paper-title-lora-2021')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('论文题目已复制'), findsNothing);
    expect(copiedText, title);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('paper tabs animate content and actions keep shared state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    final pagesSize = tester.getSize(
      find.byKey(const ValueKey('paper-tab-pages')).first,
    );
    await tester.tap(find.text('中文摘要').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byKey(const ValueKey('paper-tab-pages')).first),
      pagesSize,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('LoRA 是一种参数高效'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

    await tester.tap(find.byIcon(Icons.bookmark_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_border_rounded), findsWidgets);
  });

  testWidgets('abstract expansion appears only when text exceeds its viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final longController = PaperController(
      _TestPaperRepository(_testPaper(List.filled(120, 'LoRA').join(' '))),
    );
    addTearDown(longController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PapersScreen(controller: longController)),
      ),
    );
    await tester.pump();

    expect(find.text('展开全文'), findsOneWidget);
    await tester.tap(find.text('展开全文'));
    await tester.pump();
    expect(find.byKey(const ValueKey('paper-tab-scroll')), findsOneWidget);

    final shortController = PaperController(
      _TestPaperRepository(_testPaper('A short abstract.')),
    );
    addTearDown(shortController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PapersScreen(controller: shortController)),
      ),
    );
    await tester.pump();

    expect(find.text('展开全文'), findsNothing);
  });

  testWidgets('paper layout switches between fullscreen and grid',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey('paper-feed'))).height,
        greaterThan(700));
    expect(find.textContaining('被引 1,234'), findsOneWidget);
    expect(find.text('中文摘要'), findsWidgets);

    await tester.tap(find.text('Papers ⇄'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-grid')), findsOneWidget);
    expect(find.text('‹ 返回'), findsOneWidget);

    await tester.tap(find.textContaining('Mamba: Linear-Time'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-feed')), findsOneWidget);
    expect(find.textContaining('Mamba: Linear-Time'), findsOneWidget);
    expect(find.text('Papers ⇄'), findsOneWidget);
  });

  testWidgets('comments sheet switches to AI conversation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('评论 128'), findsOneWidget);
    expect(find.text('AI 解析'), findsOneWidget);
    expect(find.text('Lin Zhang'), findsOneWidget);

    final halfHeight = tester
        .getSize(find.byKey(const ValueKey('paper-comments-sheet')))
        .height;
    final contentSize =
        tester.getSize(find.byKey(const ValueKey('paper-sheet-pages')));
    expect(halfHeight, inInclusiveRange(350, 450));

    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    final fullHeight = tester
        .getSize(find.byKey(const ValueKey('paper-comments-sheet')))
        .height;
    expect(fullHeight, greaterThan(700));

    await tester.tap(find.byTooltip('恢复半屏'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI 解析'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('paper-sheet-pages'))),
      contentSize,
    );
    expect(find.text('解释核心方法'), findsOneWidget);
    expect(find.text('问 AI 或按住说话'), findsOneWidget);
  });

  testWidgets('comments and local AI messages complete their send flow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPaperCommentsSheet(
                context,
                demoPapers.first,
                aiService: const _FakePaperAiService(),
              ),
              child: const Text('打开评论'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开评论'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '这是一条本地评论');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('这是一条本地评论'), findsOneWidget);

    await tester.tap(find.text('AI 解析'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '总结实验效果');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.textContaining('DeepSeek Markdown'), findsOneWidget);
  });

  testWidgets('more paper topics can be selected from the add button',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    await tester.tap(find.byTooltip('添加主题'));
    await tester.pumpAndSettle();

    expect(find.text('选择主题'), findsOneWidget);
    await tester.tap(find.text('AI Agent'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('AI Agent'), findsOneWidget);
  });
}

class _FakePaperAiService implements PaperAiService {
  const _FakePaperAiService();

  @override
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return '**DeepSeek Markdown**\n\n- ${paper.title}\n- ${conversation.last.content}';
  }
}

class _TestPaperRepository implements PaperRepository {
  const _TestPaperRepository(this.paper);

  final PaperRecord paper;

  @override
  List<PaperRecord> getAll() => [paper];
}

PaperRecord _testPaper(String abstractText) {
  return PaperRecord(
    id: 'test-paper',
    venue: 'TestConf 2026',
    title: 'A Test Paper for Reading Layout',
    authors: 'Alex Chen, Lin Zhang',
    firstAffiliation: 'PaperFlow Lab',
    topics: const ['Testing'],
    abstractText: abstractText,
    chineseAbstractMarkdown: '**中文摘要**',
    relatedPapersMarkdown: '- Related paper',
    readMinutes: 5,
    citations: '0',
    likes: '0',
    comments: '0',
    saves: '0',
    shares: '0',
    accent: PaperAccent.blue,
  );
}
