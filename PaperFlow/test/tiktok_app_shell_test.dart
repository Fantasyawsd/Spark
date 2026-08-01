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

    expect(find.text('社区'), findsNothing);
    expect(find.text('私信'), findsNothing);
    expect(find.text('通知'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pump();
    expect(find.text('PaperFlow 主聊天'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pump();
    expect(find.text('Alex Chen'), findsOneWidget);
  });
}
