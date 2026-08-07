import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/data/demo_paper_repository.dart';
import 'package:spark/src/features/papers/domain/favorite_group.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/profile/presentation/paper_shelf_list_screen.dart';

void main() {
  final papers = const DemoPaperRepository().getAll();
  final groups = [
    const FavoriteGroup.defaultGroup(),
    FavoriteGroup(id: 'g2', name: '重点阅读'),
  ];
  final papersByGroup = <String, List<Paper>>{
    defaultFavoriteGroupId: [papers[0], papers[1]],
    'g2': [papers[2]],
  };

  Widget wrap(Widget screen) => MaterialApp(home: screen);

  testWidgets('flat list shows all papers and opens a paper', (tester) async {
    String? openedId;
    await tester.pumpWidget(
      wrap(PaperShelfListScreen.flat(
        title: '稍后阅读',
        papers: [papers[0], papers[1]],
        onOpenPaper: (id) => openedId = id,
      )),
    );

    expect(find.byType(PaperShelfListScreen), findsOneWidget);
    expect(find.text('稍后阅读'), findsOneWidget);
    expect(find.byKey(ValueKey('paper-shelf-row-${papers[0].id}')),
        findsOneWidget);
    expect(find.byKey(ValueKey('paper-shelf-row-${papers[1].id}')),
        findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('paper-shelf-row-${papers[0].id}')),
    );
    expect(openedId, papers[0].id);
  });

  testWidgets('flat list shows an empty state', (tester) async {
    await tester.pumpWidget(
      wrap(PaperShelfListScreen.flat(
        title: '阅读历史',
        papers: const [],
        onOpenPaper: (_) {},
      )),
    );

    expect(find.byKey(const ValueKey('paper-shelf-empty')), findsOneWidget);
    expect(find.text('还没有内容'), findsOneWidget);
  });

  testWidgets('collection list switches paper groups via chips',
      (tester) async {
    await tester.pumpWidget(
      wrap(PaperShelfListScreen.collection(
        title: '我的收藏',
        groups: groups,
        papersByGroup: papersByGroup,
        onOpenPaper: (_) {},
      )),
    );

    expect(find.byKey(ValueKey('paper-shelf-row-${papers[0].id}')),
        findsOneWidget);
    expect(
        find.byKey(ValueKey('paper-shelf-row-${papers[2].id}')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('paper-shelf-group-g2')));
    await tester.pump();

    expect(find.byKey(ValueKey('paper-shelf-row-${papers[2].id}')),
        findsOneWidget);
    expect(
        find.byKey(ValueKey('paper-shelf-row-${papers[0].id}')), findsNothing);
  });
}
