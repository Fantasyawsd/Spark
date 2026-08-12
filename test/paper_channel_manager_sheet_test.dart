import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_channel_manager_sheet.dart';

void main() {
  Future<List<UserPaperChannel>> openSheet(
    WidgetTester tester, {
    List<UserPaperChannel> initial = const [],
    required ValueChanged<List<UserPaperChannel>> onChannelsChanged,
    bool showConferenceChannels = false,
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
                  showConferenceChannels: showConferenceChannels,
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

    expect(find.text('已添加频道'), findsNothing);
    expect(find.byKey(const ValueKey('paper-channel-manager-tabs')),
        findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('会议'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('paper-channel-subject-cs.LG')),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('paper-channel-subject-cs.AI')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-channel-subject-cs.AI')));
    await tester.pump();
    expect(lastSaved!.map((channel) => channel.id), ['cs.LG', 'cs.AI']);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('paper-channel-subject-cs.AI')),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('paper-channel-subject-cs.LG')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-channel-subject-cs.LG')));
    await tester.pump();
    expect(lastSaved!.map((channel) => channel.id), ['cs.AI']);

    await tester.ensureVisible(
      find.byKey(const ValueKey('paper-channel-subject-cs.AI')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-channel-subject-cs.AI')));
    await tester.pump();
    expect(lastSaved, isEmpty);
  });

  testWidgets('lists all catalog topics directly', (tester) async {
    await openSheet(tester, onChannelsChanged: (_) {});

    for (final code in ['cs.AI', 'cs.CL', 'cs.CV', 'cs.LG']) {
      expect(
          find.byKey(ValueKey('paper-channel-subject-$code')), findsOneWidget);
    }
  });

  testWidgets('conference tab adds and removes real conference channels',
      (tester) async {
    List<UserPaperChannel>? lastSaved;
    await openSheet(
      tester,
      onChannelsChanged: (channels) => lastSaved = channels,
      showConferenceChannels: true,
    );

    await tester.tap(find.text('会议'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paper-channel-conference-ICML')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('paper-channel-conference-NeurIPS')),
        findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('paper-channel-conference-ICML')),
    );
    await tester.pump();
    expect(lastSaved, hasLength(1));
    expect(lastSaved!.single.kind, PaperChannelKind.conference);
    expect(lastSaved!.single.id, 'ICML');

    await tester.tap(
      find.byKey(const ValueKey('paper-channel-conference-ICML')),
    );
    await tester.pump();
    expect(lastSaved, isEmpty);
  });
}
