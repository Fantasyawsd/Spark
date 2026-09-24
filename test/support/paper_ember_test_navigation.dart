import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Traverse the production discovery-to-reader route, including asynchronous load.
Future<void> openFirstDiscoveredPaper(WidgetTester tester) async {
  final open = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('paper-discovery-open-');
  }).first;
  await tester.tap(open);
  await tester.pumpAndSettle();
}

Future<void> openPaperMore(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('paper-action-more')));
  await tester.pumpAndSettle();
}

Future<void> selectReaderSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}
