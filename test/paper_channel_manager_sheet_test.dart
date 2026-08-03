import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/features/papers/presentation/widgets/paper_channel_manager_sheet.dart';

void main() {
  Future<List<UserPaperChannel>> openSheet(
    WidgetTester tester, {
    List<UserPaperChannel> initial = const [],
    required ValueChanged<List<UserPaperChannel>> onChannelsChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPaperChannelManagerSheet(
                  context,
                  userChannels: initial,
                  onChannelsChanged: onChannelsChanged,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return initial;
  }

  const machineLearning = UserPaperChannel(
    kind: PaperChannelKind.subject,
    id: 'cs.LG',
    displayName: '机器学习',
  );

  testWidgets('adds and removes subject channels with live callbacks',
      (tester) async {
    List<UserPaperChannel>? lastSaved;
    await openSheet(
      tester,
      initial: const [machineLearning],
      onChannelsChanged: (channels) => lastSaved = channels,
    );

    expect(find.text('已添加频道'), findsOneWidget);
    expect(find.text('按主题'), findsOneWidget);
    await tester.ensureVisible(find.text('按会议'));
    await tester.pump();
    expect(find.text('按会议'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('paper-channel-subject-cs.AI')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-channel-subject-cs.AI')));
    await tester.pump();
    expect(lastSaved!.map((channel) => channel.id), ['cs.LG', 'cs.AI']);

    await tester.ensureVisible(
      find.byKey(const ValueKey('paper-channel-remove-subject:cs.LG')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('paper-channel-remove-subject:cs.LG')),
    );
    await tester.pump();
    expect(lastSaved!.map((channel) => channel.id), ['cs.AI']);

    await tester.ensureVisible(
      find.byKey(const ValueKey('paper-channel-subject-cs.AI')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-channel-subject-cs.AI')));
    await tester.pump();
    expect(lastSaved, isEmpty);
    expect(find.text('已添加频道'), findsNothing);
  });

  testWidgets('search narrows the catalog by name and code', (tester) async {
    await openSheet(tester, onChannelsChanged: (_) {});

    await tester.enterText(
      find.byKey(const ValueKey('paper-channel-search')),
      '机器',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('paper-channel-subject-cs.LG')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('paper-channel-subject-cs.AI')),
        findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('paper-channel-search')),
      'cs.cv',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('paper-channel-subject-cs.CV')),
        findsOneWidget);
    expect(find.text('没有匹配的主题。'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('paper-channel-search')),
      '量子',
    );
    await tester.pump();
    expect(find.text('没有匹配的主题。'), findsOneWidget);
  });

  testWidgets('conference section is visible but not addable', (tester) async {
    await openSheet(tester, onChannelsChanged: (_) {});

    await tester.ensureVisible(
      find.text('会议频道尚未开放，真实会议数据源接入后可编辑。'),
    );
    await tester.pump();
    expect(
      find.text('会议频道尚未开放，真实会议数据源接入后可编辑。'),
      findsOneWidget,
    );
  });
}
