import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';

void main() {
  final papers = const DemoPaperRepository().getAll();

  Widget wrap(ProfileScreen screen) =>
      MaterialApp(home: Scaffold(body: screen));

  ProfileScreen buildScreen() {
    return ProfileScreen(
      favoriteGroups: const [FavoriteGroup.defaultGroup()],
      favoritePapersByGroup: {
        defaultFavoriteGroupId: [papers[0]],
      },
      savedCount: 1,
      readLaterPapers: [papers[1]],
      readingHistory: [papers[2]],
      onOpenPaper: (_) {},
    );
  }

  testWidgets('tapping the saved stat opens the collection list',
      (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(find.byType(PaperShelfListScreen), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.byKey(ValueKey('paper-shelf-row-${papers[0].id}')),
        findsOneWidget);
  });

  testWidgets('tapping the read later stat opens its flat list',
      (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));

    await tester.tap(find.text('稍后阅读').first);
    await tester.pumpAndSettle();

    expect(find.byType(PaperShelfListScreen), findsOneWidget);
    expect(find.byKey(ValueKey('paper-shelf-row-${papers[1].id}')),
        findsOneWidget);
  });

  testWidgets('tapping the history stat opens its flat list', (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));

    await tester.tap(find.text('阅读历史').first);
    await tester.pumpAndSettle();

    expect(find.byType(PaperShelfListScreen), findsOneWidget);
    expect(find.byKey(ValueKey('paper-shelf-row-${papers[2].id}')),
        findsOneWidget);
  });

  testWidgets('tapping the view-all action opens the flat list',
      (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));

    await tester.tap(find.text('共 1 篇').first);
    await tester.pumpAndSettle();

    expect(find.byType(PaperShelfListScreen), findsOneWidget);
    expect(find.byKey(ValueKey('paper-shelf-row-${papers[1].id}')),
        findsOneWidget);
  });
}
