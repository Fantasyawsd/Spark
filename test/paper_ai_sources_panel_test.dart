import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/presentation/widgets/paper_ai_sources_panel.dart';

void main() {
  testWidgets('source opener failures report once and keep user feedback',
      (tester) async {
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaperAiSourcesPanel(
              sources: const [
                ChatSource(
                  title: '来源一',
                  url: 'https://example.test/source',
                ),
              ],
              onOpenSource: (uri) async {
                throw StateError('private-source-query');
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('paper-ai-sources-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paper-ai-source-1')));
      await tester.pump();
    });

    expect(find.text('无法打开来源链接'), findsOneWidget);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.chatOpenSource],
    );
    expect(events.single.summary, isNot(contains('private-source-query')));
  });
}
