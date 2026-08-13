import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/presentation/widgets/paper_ai_chat_app_bar.dart';
import 'package:spark/src/features/papers/data/paper_pdf_extraction_service.dart';

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

  testWidgets('mapped PDF download failures report once at the final boundary',
      (tester) async {
    final events = <SparkDiagnosticEvent>[];
    final extractionService = PaperPdfExtractionService(
      client: _ThrowingPdfClient(),
    );

    await SparkDiagnostics.runWithSink(events.add, () async {
      await tester.pumpWidget(_fullTextFailureApp(
        onLoadFullText: () async {
          await extractionService.download(
            Uri.parse('https://example.test/private-paper.pdf'),
          );
          throw StateError('unreachable');
        },
      ));

      await tester.tap(find.byKey(const ValueKey('paper-ai-fulltext-toggle')));
      await tester.pumpAndSettle();
    });

    _expectRetryableFullTextFailure(tester, events);
    expect(events.single.errorType, 'PaperPdfException');
    expect(
      events.single.stackTrace.toString(),
      contains('_ThrowingPdfClient.send'),
    );
  });

  testWidgets('mapped PDF worker failures report once at the final boundary',
      (tester) async {
    final events = <SparkDiagnosticEvent>[];
    final extractionService = PaperPdfExtractionService();

    await SparkDiagnostics.runWithSink(events.add, () async {
      await tester.pumpWidget(_fullTextFailureApp(
        onLoadFullText: () async {
          await extractionService.extract(
            paperId: 'private-paper',
            version: 'v1',
            bytes: const [0x25, 0x50, 0x44, 0x46, 0x2d],
          );
          throw StateError('unreachable');
        },
      ));

      await tester.tap(find.byKey(const ValueKey('paper-ai-fulltext-toggle')));
      await tester.pumpAndSettle();
    });

    _expectRetryableFullTextFailure(tester, events);
    expect(events.single.errorType, 'PaperPdfException');
    expect(
      events.single.stackTrace.toString(),
      contains('PaperPdfExtractionService._runExtractionWorker'),
    );
  });
}

Widget _fullTextFailureApp({
  required Future<ChatContext> Function() onLoadFullText,
}) {
  return MaterialApp(
    home: Scaffold(
      appBar: PaperAiChatAppBar(
        initialTitle: '标题',
        subtitle: '论文标题',
        previewMode: false,
        onPreviewModeChanged: (_) {},
        onOpenSettings: () {},
        onApplyFullText: (_) => true,
        fullTextAvailable: true,
        onLoadFullText: onLoadFullText,
        selectionActive: false,
        selectionCount: 0,
        onCancelSelection: () {},
      ),
    ),
  );
}

void _expectRetryableFullTextFailure(
  WidgetTester tester,
  List<SparkDiagnosticEvent> events,
) {
  expect(find.text('无法读取论文全文，请稍后重试。'), findsOneWidget);
  expect(
    events.map((event) => event.operation),
    [SparkDiagnosticOperation.chatLoadFullText],
  );
  expect(events.single.summary, isNot(contains('private')));
  expect(
    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('paper-ai-fulltext-toggle')),
        )
        .tooltip,
    '读取论文全文',
  );
}

final class _ThrowingPdfClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError('private-pdf-path');
  }
}
