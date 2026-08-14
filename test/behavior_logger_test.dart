import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/features/behavior/application/behavior_logger.dart';
import 'package:spark/src/features/behavior/data/behavior_consent_store.dart';
import 'package:spark/src/features/behavior/data/behavior_event_store.dart';
import 'package:spark/src/features/behavior/domain/behavior_event.dart';

void main() {
  late Directory tempDir;
  late BehaviorEventStore events;
  late BehaviorConsentStore consent;
  late BehaviorLogger logger;

  String path(String name) => '${tempDir.path}${Platform.pathSeparator}$name';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('behavior_test');
    events = BehaviorEventStore(
      store: LocalJsonStore(fileName: 'events.json', file: File(path('events.json'))),
    );
    consent = BehaviorConsentStore(
      store: LocalJsonStore(fileName: 'consent.json', file: File(path('consent.json'))),
    );
    logger = BehaviorLogger(consent: consent, events: events);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('事件校验：空 paperId 拒绝', () {
    expect(
      () => BehaviorEvent(
        type: BehaviorEventType.paperOpened,
        paperId: '  ',
        occurredAt: DateTime.utc(2026, 8, 14),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('logger 默认同意时记录打开事件', () async {
    await logger.logPaperOpened('paper-1');
    expect(await events.count(), 1);
    final all = await events.events();
    expect(all.single.type, BehaviorEventType.paperOpened);
    expect(all.single.paperId, 'paper-1');
  });

  test('同意关闭后丢弃事件并可清除', () async {
    await logger.logPaperOpened('paper-1');
    await consent.setEnabled(false);
    await logger.logPaperLiked('paper-2');
    expect(await events.count(), 1);
    await logger.clearEvents();
    expect(await events.count(), 0);
  });

  test('保留期外事件在 append 时滚动清理', () async {
    var now = DateTime.utc(2026, 8, 14);
    final clockedEvents = BehaviorEventStore(
      store: LocalJsonStore(fileName: 'clocked.json', file: File(path('clocked.json'))),
      clock: () => now,
    );
    final clockedLogger = BehaviorLogger(
      consent: consent,
      events: clockedEvents,
      clock: () => now,
    );
    await clockedLogger.logPaperOpened('old-paper');
    now = now.add(const Duration(days: 91));
    await clockedLogger.logPaperLiked('new-paper');
    final all = await clockedEvents.events();
    expect(all.map((event) => event.paperId), ['new-paper']);
  });

  test('条目上限裁剪最旧事件', () async {
    final bounded = BehaviorEventStore(
      store: LocalJsonStore(fileName: 'bounded.json', file: File(path('bounded.json'))),
      maxEntries: 3,
    );
    final boundedLogger = BehaviorLogger(consent: consent, events: bounded);
    for (var index = 0; index < 5; index++) {
      await boundedLogger.logPaperOpened('paper-$index');
    }
    final all = await bounded.events();
    expect(all.map((event) => event.paperId), ['paper-2', 'paper-3', 'paper-4']);
  });

  test('事件 JSON 往返一致', () {
    final event = BehaviorEvent(
      type: BehaviorEventType.paperSaved,
      paperId: 'paper-x',
      occurredAt: DateTime.utc(2026, 8, 14, 10, 30),
      context: const {'subject': 'cs.AI'},
    );
    final restored = BehaviorEvent.fromJson(event.toJson());
    expect(restored.type, event.type);
    expect(restored.paperId, event.paperId);
    expect(restored.occurredAt, event.occurredAt);
    expect(restored.context, event.context);
  });
}
