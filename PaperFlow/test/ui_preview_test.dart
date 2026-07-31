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

    await tester.tap(find.text('AI 解析'));
    await tester.pumpAndSettle();

    expect(find.text('解释核心方法'), findsOneWidget);
    expect(find.text('问 AI 或按住说话'), findsOneWidget);
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
