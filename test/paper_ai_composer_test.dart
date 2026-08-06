import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/features/chat/presentation/widgets/paper_ai_model_avatar.dart';
import 'package:paperflow/src/features/papers/presentation/widgets/paper_ai_composer.dart';

void main() {
  testWidgets(
      'composer adapts to multiline input while keeping the toolbar attached',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PaperAiComposer(
              controller: controller,
              enabled: true,
              sending: false,
              reasoningEffort: PaperAiReasoningEffort.high,
              onReasoningEffortChanged: (_) {},
              webSearchAvailable: true,
              webSearchEnabled: false,
              onWebSearchChanged: (_) {},
              hasContext: false,
              onClearContext: () {},
              onChanged: (_) {},
              onSend: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    final surface = find.byKey(
      const ValueKey('paper-ai-composer-surface'),
    );
    final toolbar = find.byKey(
      const ValueKey('paper-ai-composer-toolbar'),
    );
    final initialToolbarRect = tester.getRect(toolbar);
    final initialSurfaceRect = tester.getRect(surface);
    expect(
      initialSurfaceRect.bottom - initialToolbarRect.bottom,
      inInclusiveRange(6, 8),
    );

    await tester.enterText(
      find.byKey(const ValueKey('paper-ai-input')),
      '第一行\n第二行\n第三行\n第四行\n第五行',
    );
    await tester.pump();

    final expandedToolbarRect = tester.getRect(toolbar);
    final expandedSurfaceRect = tester.getRect(surface);
    expect(expandedSurfaceRect.height, greaterThan(initialSurfaceRect.height));
    expect(expandedToolbarRect.bottom, closeTo(initialToolbarRect.bottom, 0.1));
    expect(
      expandedSurfaceRect.bottom - expandedToolbarRect.bottom,
      inInclusiveRange(6, 8),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear context remains visible on a narrow phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PaperAiComposer(
              controller: controller,
              enabled: true,
              sending: false,
              reasoningEffort: PaperAiReasoningEffort.high,
              onReasoningEffortChanged: (_) {},
              webSearchAvailable: true,
              webSearchEnabled: false,
              onWebSearchChanged: (_) {},
              hasContext: false,
              onClearContext: () {},
              onChanged: (_) {},
              onSend: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    final clear = find.byKey(const ValueKey('paper-ai-clear-context'));
    expect(clear, findsOneWidget);
    expect(tester.getRect(clear).right, lessThanOrEqualTo(378));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI composer opens the reasoning depth picker', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var effort = PaperAiReasoningEffort.high;
    var webSearch = false;
    var cleared = false;

    Widget build() {
      return MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.bottomCenter,
              child: PaperAiComposer(
                controller: controller,
                enabled: true,
                sending: false,
                reasoningEffort: effort,
                onReasoningEffortChanged: (value) =>
                    setState(() => effort = value),
                webSearchAvailable: true,
                webSearchEnabled: webSearch,
                onWebSearchChanged: (value) =>
                    setState(() => webSearch = value),
                hasContext: true,
                onClearContext: () => cleared = true,
                onChanged: (_) {},
                onSend: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build());
    await tester.tap(find.byKey(const ValueKey('paper-ai-web-search')));
    expect(webSearch, isTrue);

    await tester.tap(find.byKey(const ValueKey('paper-ai-clear-context')));
    expect(cleared, isTrue);

    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-setting')));
    await tester.pumpAndSettle();
    expect(find.text('调整模型思考深度'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('paper-ai-reasoning-option-none')),
    );
    expect(effort, PaperAiReasoningEffort.none);
    Navigator.of(tester.element(find.text('调整模型思考深度'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-setting')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('paper-ai-reasoning-option-high')),
    );
    expect(effort, PaperAiReasoningEffort.high);
    Navigator.of(tester.element(find.text('调整模型思考深度'))).pop();
  });

  testWidgets('deep thinking picker supports enabled and disabled states',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var effort = PaperAiReasoningEffort.none;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PaperAiComposer(
              controller: controller,
              enabled: true,
              sending: false,
              reasoningEffort: effort,
              onReasoningEffortChanged: (value) =>
                  setState(() => effort = value),
              webSearchAvailable: false,
              webSearchEnabled: false,
              onWebSearchChanged: (_) {},
              hasContext: false,
              onClearContext: () {},
              onChanged: (_) {},
              onSend: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-setting')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('paper-ai-reasoning-option-high')),
    );
    expect(effort, PaperAiReasoningEffort.high);
    Navigator.of(tester.element(find.text('调整模型思考深度'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-setting')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('paper-ai-reasoning-option-none')),
    );
    expect(effort, PaperAiReasoningEffort.none);
  });

  testWidgets('model sheet shows the model avatar instead of a plain icon',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PaperAiComposer(
              controller: controller,
              enabled: true,
              sending: false,
              reasoningEffort: PaperAiReasoningEffort.high,
              onReasoningEffortChanged: (_) {},
              webSearchAvailable: true,
              webSearchEnabled: false,
              onWebSearchChanged: (_) {},
              hasContext: false,
              onClearContext: () {},
              onChanged: (_) {},
              onSend: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('paper-ai-model-setting')));
    await tester.pumpAndSettle();

    expect(find.text('选择模型'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(PaperAiModelAvatar),
      ),
      findsWidgets,
    );
    // PaperAiModelAvatar 自带 auto_awesome 图标作为加载失败回退，因此这里只断言
    // 模型面板以头像组件承载模型入口，而不是直接显示裸图标。
    final sheetAvatars = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(PaperAiModelAvatar),
    );
    expect(sheetAvatars, findsWidgets);
    expect(
      find.descendant(of: sheetAvatars.first, matching: find.byType(Icon)),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
