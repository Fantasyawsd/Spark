import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/data/demo_paper_repository.dart';
import 'package:spark/src/features/papers/domain/favorite_group.dart';
import 'package:spark/src/features/profile/presentation/paper_shelf_list_screen.dart';
import 'package:spark/src/features/profile/presentation/profile_screen.dart';

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

  testWidgets('collection callback overrides the default navigation',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      wrap(ProfileScreen(
        savedCount: 1,
        onOpenFavoriteCollection: () => opened = true,
      )),
    );

    await tester.tap(find.text('收藏'));
    await tester.pump();

    expect(opened, isTrue);
    expect(find.byType(PaperShelfListScreen), findsNothing);
  });

  testWidgets('local data entry uses injected description and callback',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      wrap(ProfileScreen(
        localDataDescriptionBuilder: () => '占用 12 MB',
        onOpenLocalData: () => opened = true,
      )),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-local-data')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('占用 12 MB'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-local-data')));
    expect(opened, isTrue);
  });

  test('profile page does not import sibling presentation layers', () async {
    final source = await File(
      'lib/src/features/profile/presentation/profile_screen.dart',
    ).readAsString();

    expect(source, isNot(contains('local_data/presentation')));
    expect(source, isNot(contains('papers/presentation')));
  });
}
