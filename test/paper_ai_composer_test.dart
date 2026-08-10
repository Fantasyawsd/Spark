import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/chat.dart';
import 'package:spark/src/features/chat/presentation/widgets/paper_ai_composer.dart';
import 'package:spark/src/features/chat/presentation/widgets/paper_ai_model_avatar.dart';

void main() {
  testWidgets(
    'composer keeps a transparent toolbar above the expanding input surface',
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
                reasoningEffort: ChatReasoningEffort.high,
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

      final surface = find.byKey(const ValueKey('paper-ai-composer-surface'));
      final toolbar = find.byKey(const ValueKey('paper-ai-composer-toolbar'));
      final send = find.byKey(const ValueKey('paper-ai-send'));
      final initialToolbarRect = tester.getRect(toolbar);
      final initialSurfaceRect = tester.getRect(surface);
      final initialSendRect = tester.getRect(send);

      expect(
        find.ancestor(of: toolbar, matching: surface),
        findsNothing,
        reason: '功能按钮应位于输入框装饰容器之外，以保持透明悬浮效果',
      );
      expect(
        initialSurfaceRect.top - initialToolbarRect.bottom,
        closeTo(2, 0.1),
      );
      expect(
        initialSurfaceRect.contains(initialSendRect.topLeft) &&
            initialSurfaceRect.contains(initialSendRect.bottomRight),
        isTrue,
        reason: '发送按钮应保留在输入框内',
      );

      await tester.enterText(
        find.byKey(const ValueKey('paper-ai-input')),
        '第一行\n第二行\n第三行\n第四行\n第五行',
      );
      await tester.pump();

      final expandedToolbarRect = tester.getRect(toolbar);
      final expandedSurfaceRect = tester.getRect(surface);
      expect(
        expandedSurfaceRect.height,
        greaterThan(initialSurfaceRect.height),
      );
      expect(
        expandedSurfaceRect.bottom,
        closeTo(initialSurfaceRect.bottom, 0.1),
      );
      expect(
        expandedSurfaceRect.top - expandedToolbarRect.bottom,
        closeTo(2, 0.1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clear context remains visible on a narrow phone', (
    tester,
  ) async {
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
              reasoningEffort: ChatReasoningEffort.high,
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

  testWidgets('AI composer opens the compact reasoning intensity picker', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var effort = ChatReasoningEffort.high;
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
    expect(find.text('模型思考强度'), findsOneWidget);
    expect(find.text('调整模型思考深度'), findsNothing);
    expect(
      find.text('并非所有模型都支持深度调整。请参考模型和提供商文档。'),
      findsNothing,
    );
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(320),
    );
    expect(
      find.byKey(const ValueKey('paper-ai-reasoning-option-low')),
      findsNothing,
    );
    for (final effort in const ['none', 'medium', 'high', 'max']) {
      expect(
        find.byKey(ValueKey('paper-ai-reasoning-option-$effort')),
        findsOneWidget,
      );
    }
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);
    expect(find.text('极致'), findsOneWidget);
    expect(find.text('低'), findsNothing);
    expect(find.text('中等'), findsNothing);
    expect(find.text('超高'), findsNothing);

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('paper-ai-reasoning-slider')),
    );
    expect(slider.divisions, 3);
    final sliderTheme = tester.widget<SliderTheme>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('paper-ai-reasoning-slider')),
            matching: find.byType(SliderTheme),
          )
          .first,
    );
    expect(sliderTheme.data.trackHeight, 18);
    final thumbShape = sliderTheme.data.thumbShape as RoundSliderThumbShape;
    expect(thumbShape.enabledThumbRadius, 22);

    await tester.tap(
      find.byKey(const ValueKey('paper-ai-reasoning-option-medium')),
    );
    expect(effort, ChatReasoningEffort.medium);
    await tester.tap(
      find.byKey(const ValueKey('paper-ai-reasoning-option-none')),
    );
    expect(effort, ChatReasoningEffort.none);
    Navigator.of(tester.element(find.text('模型思考强度'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-setting')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('paper-ai-reasoning-option-max')),
    );
    expect(effort, ChatReasoningEffort.max);
    Navigator.of(tester.element(find.text('模型思考强度'))).pop();
  });

  testWidgets('deep thinking picker supports enabled and disabled states', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var effort = ChatReasoningEffort.none;

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
    expect(effort, ChatReasoningEffort.high);
    Navigator.of(tester.element(find.text('模型思考强度'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-setting')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('paper-ai-reasoning-option-none')),
    );
    expect(effort, ChatReasoningEffort.none);
  });

  testWidgets('reasoning sheet normalizes unsupported effort on open', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var effort = ChatReasoningEffort.low;

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

    expect(effort, ChatReasoningEffort.medium);
    expect(
      find.byKey(const ValueKey('paper-ai-reasoning-option-medium')),
      findsOneWidget,
    );
    Navigator.of(tester.element(find.text('模型思考强度'))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('model sheet keeps only the centered model name and avatar', (
    tester,
  ) async {
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
              reasoningEffort: ChatReasoningEffort.high,
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

    expect(find.text('选择模型'), findsNothing);
    expect(find.text('Chat · text → text · DeepSeek'), findsNothing);
    final option = find.byKey(const ValueKey('paper-ai-model-option'));
    final modelName = find.text('deepseek-v4-flash');
    expect(option, findsOneWidget);
    expect(modelName, findsOneWidget);
    expect(
      tester.getCenter(modelName).dx,
      closeTo(tester.getCenter(option).dx, 0.5),
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(PaperAiModelAvatar),
      ),
      findsWidgets,
    );
    // PaperAiModelAvatar 以内置 DeepSeek 标识呈现模型提供方，因此这里断言
    // 模型面板以头像组件承载模型入口，而不是直接显示裸图标。
    final sheetAvatars = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(PaperAiModelAvatar),
    );
    expect(sheetAvatars, findsWidgets);
    expect(
      find.descendant(of: sheetAvatars.first, matching: find.byType(Image)),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
