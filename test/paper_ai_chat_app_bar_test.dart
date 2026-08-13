import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/presentation/widgets/paper_ai_chat_app_bar.dart';

void main() {
  testWidgets('title and full-text state survive selection mode changes', (
    tester,
  ) async {
    var selectionActive = false;
    var fullTextLoads = 0;

    Widget buildApp() {
      return MaterialApp(
        home: Scaffold(
          appBar: PaperAiChatAppBar(
            initialTitle: '初始标题',
            subtitle: '论文标题',
            previewMode: false,
            onPreviewModeChanged: (_) {},
            onOpenSettings: () {},
            onApplyFullText: (_) => true,
            fullTextAvailable: true,
            onLoadFullText: () async {
              fullTextLoads++;
              return const ChatContext(
                id: 'paper-1',
                title: '论文标题',
                systemPrompt: '全文上下文',
              );
            },
            selectionActive: selectionActive,
            selectionCount: selectionActive ? 2 : 0,
            onCancelSelection: () {},
          ),
        ),
      );
    }

    await tester.pumpWidget(buildApp());
    await tester.tap(find.byKey(const ValueKey('paper-ai-title')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paper-ai-title-input')),
      '保留的标题',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paper-ai-fulltext-toggle')));
    await tester.pumpAndSettle();

    selectionActive = true;
    await tester.pumpWidget(buildApp());
    expect(find.text('选择消息'), findsOneWidget);

    selectionActive = false;
    await tester.pumpWidget(buildApp());
    expect(find.text('保留的标题'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('paper-ai-fulltext-toggle')),
          )
          .tooltip,
      '已读取全文',
    );
    expect(fullTextLoads, 1);
  });

  testWidgets('full-text failures report once and reset loading state',
      (tester) async {
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: PaperAiChatAppBar(
              initialTitle: '标题',
              subtitle: '论文标题',
              previewMode: false,
              onPreviewModeChanged: (_) {},
              onOpenSettings: () {},
              onApplyFullText: (_) => true,
              fullTextAvailable: true,
              onLoadFullText: () async {
                throw StateError('private-pdf-path');
              },
              selectionActive: false,
              selectionCount: 0,
              onCancelSelection: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('paper-ai-fulltext-toggle')));
      await tester.pumpAndSettle();
    });

    expect(find.text('无法读取论文全文，请稍后重试。'), findsOneWidget);
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.chatLoadFullText],
    );
    expect(events.single.summary, isNot(contains('private-pdf-path')));
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('paper-ai-fulltext-toggle')),
          )
          .tooltip,
      '读取论文全文',
    );
  });
}
