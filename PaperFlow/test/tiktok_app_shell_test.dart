import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  testWidgets('PaperFlow shell renders and switches main pages',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    expect(find.text('LoRA: Low-Rank Adaptation of Large Language Models'),
        findsOneWidget);

    await tester.tap(find.text('社区'));
    await tester.pump();
    expect(find.text('社区'), findsOneWidget);

    await tester.tap(find.text('消息'));
    await tester.pump();
    expect(find.text('消息'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(find.text('Alex Chen'), findsOneWidget);
  });
}
