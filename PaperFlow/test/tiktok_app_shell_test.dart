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

    expect(
      find.text(
        'Corruption Robust Offline Reinforcement Learning with Human Feedback',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('社区'));
    await tester.pump();
    expect(find.text('社区'), findsOneWidget);

    await tester.tap(find.text('聊天'));
    await tester.pump();
    expect(find.text('AI 聊天'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(find.text('Alex Chen'), findsOneWidget);
  });
}
