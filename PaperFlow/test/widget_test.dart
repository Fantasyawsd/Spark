import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  testWidgets('startup shows the PaperFlow logo before opening the feed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp());

    final logo = tester.widget<Image>(find.byType(Image));
    expect(
      (logo.image as AssetImage).assetName,
      'assets/images/paperflow_logo.png',
    );

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();
    expect(find.byKey(const ValueKey('paper-feed')), findsOneWidget);
  });

  testWidgets('create button opens the PaperFlow action sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PaperFlowApp(showSplash: false));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('create-button')));
    await tester.pumpAndSettle();

    expect(find.text('创建内容'), findsOneWidget);
    expect(find.text('上传论文'), findsOneWidget);
    expect(find.text('发布动态'), findsOneWidget);
  });
}
