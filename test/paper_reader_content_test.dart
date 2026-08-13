import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_reader_content.dart';

void main() {
  testWidgets('keyword content preserves generate and refresh actions', (
    tester,
  ) async {
    var generated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperReaderKeywordContent(
            keywords: const [],
            loadingCache: false,
            generating: false,
            error: null,
            onGenerate: () => generated = true,
            onRefresh: () {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('尚未生成关键词'), findsOneWidget);
    await tester.tap(find.text('生成'));
    expect(generated, isTrue);
  });

  testWidgets('AI interpretation content retains its ChatPaper action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperReaderAiInterpretationContent(onOpen: () => opened = true),
        ),
      ),
    );

    await tester.tap(find.text('打开 ChatPaper'));
    expect(opened, isTrue);
  });
}
