import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/features/behavior/application/profile_aggregator.dart';
import 'package:spark/src/features/behavior/data/file_profile_store.dart';
import 'package:spark/src/features/behavior/domain/behavior_event.dart';
import 'package:spark/src/features/behavior/domain/user_profile.dart';

void main() {
  late DateTime now;

  PaperProfileMetadata metadata(String paperId) => (
        subjects: const ['cs.AI', 'cs.LG'],
        keywords: const ['多模态'],
        venue: 'NeurIPS',
      );

  BehaviorEvent event(BehaviorEventType type, String paperId, DateTime at) =>
      BehaviorEvent(type: type, paperId: paperId, occurredAt: at);

  setUp(() {
    now = DateTime.utc(2026, 8, 14);
  });

  test('显式信号权重大于隐式信号', () {
    final aggregator = ProfileAggregator(clock: () => now);
    final profile = aggregator.aggregate(
      [
        event(BehaviorEventType.paperOpened, 'p1', now),
        event(BehaviorEventType.paperLiked, 'p1', now),
      ],
      resolveMetadata: metadata,
      asOf: now,
    );
    expect(profile.subjects['cs.AI'], closeTo(2.5, 1e-9));
    expect(profile.keywords['多模态'], closeTo(2.5, 1e-9));
    expect(profile.venues['NeurIPS'], closeTo(2.5, 1e-9));
    expect(profile.version, UserProfile.currentVersion);
  });

  test('时间衰减：半衰期后权重减半', () {
    final aggregator = ProfileAggregator(clock: () => now);
    final halfLifeAgo = now.subtract(const Duration(days: 30));
    final profile = aggregator.aggregate(
      [event(BehaviorEventType.paperLiked, 'p1', halfLifeAgo)],
      resolveMetadata: metadata,
      asOf: now,
    );
    expect(profile.subjects['cs.AI'], closeTo(1.0, 1e-9));
  });

  test('空事件产生空画像', () {
    final aggregator = ProfileAggregator(clock: () => now);
    final profile = aggregator.aggregate(
      const [],
      resolveMetadata: metadata,
      asOf: now,
    );
    expect(profile.subjects, isEmpty);
    expect(profile.keywords, isEmpty);
    expect(profile.venues, isEmpty);
  });

  test('画像 JSON 往返一致', () {
    final profile = UserProfile(
      version: UserProfile.currentVersion,
      subjects: const {'cs.AI': 2.5},
      keywords: const {'多模态': 1.5},
      venues: const {'NeurIPS': 1.0},
      updatedAt: now,
    );
    final restored = UserProfile.fromJson(profile.toJson());
    expect(restored.subjects, profile.subjects);
    expect(restored.keywords, profile.keywords);
    expect(restored.venues, profile.venues);
    expect(restored.updatedAt, profile.updatedAt);
  });

  test('画像存储读写', () async {
    final dir = Directory.systemTemp.createTempSync('profile_test');
    final store = FileProfileStore(
      store: LocalJsonStore(
        fileName: 'user_profile.json',
        file: File('${dir.path}${Platform.pathSeparator}user_profile.json'),
      ),
    );
    try {
      expect(await store.read(), isNull);
      final profile = UserProfile.empty(updatedAt: now);
      await store.write(profile);
      final restored = await store.read();
      expect(restored, isNotNull);
      expect(restored!.version, UserProfile.currentVersion);
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
