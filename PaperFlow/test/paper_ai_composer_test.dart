import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/features/papers/presentation/widgets/paper_ai_composer.dart';

void main() {
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

  testWidgets('AI composer configures reasoning, search and context',
      (tester) async {
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
                onWebSearchChanged: (value) => webSearch = value,
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
    await tester.pump();
    expect(effort, PaperAiReasoningEffort.none);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-setting')));
    await tester.pump();
    expect(effort, PaperAiReasoningEffort.high);
  });

  testWidgets('deep thinking button toggles between enabled and disabled',
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
    await tester.pump();
    expect(effort, PaperAiReasoningEffort.high);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-ai-reasoning-setting')));
    await tester.pump();
    expect(effort, PaperAiReasoningEffort.none);
  });
}
