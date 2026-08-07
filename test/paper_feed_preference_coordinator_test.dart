import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_feed_preference_coordinator.dart';
import 'package:spark/src/features/papers/domain/paper_channel.dart';
import 'package:spark/src/features/papers/domain/paper_channel_preference_repository.dart';
import 'package:spark/src/features/papers/domain/paper_preference_repository.dart';
import 'package:spark/src/features/papers/domain/paper_time_range.dart';

void main() {
  test('loads feed and channel preference state behind a narrow API', () async {
    final coordinator = PaperFeedPreferenceCoordinator(
      preferenceRepository: _SeedPaperPreferenceRepository(),
      channelPreferenceRepository: _SeedChannelPreferenceRepository(),
    );
    addTearDown(coordinator.dispose);

    await coordinator.initializeFeedPreferences();
    await coordinator.initializeChannelPreferences();

    expect(coordinator.positionFor('fixed:recommended'), 3);
    expect(
      coordinator.timeRangeFor('fixed:recommended').storageKey,
      const PaperTimeRange.last7Days().storageKey,
    );
    expect(coordinator.legacyPrimaryIndex, 2);
    expect(coordinator.userChannels.map((channel) => channel.id), ['cs.AI']);
    expect(coordinator.selectedChannelKey, 'subject:cs.AI');
  });

  test('serial feed writes recover after an unexpected failure', () async {
    final repository = _FlakyPaperPreferenceRepository();
    final coordinator = PaperFeedPreferenceCoordinator(
      preferenceRepository: repository,
    );
    addTearDown(coordinator.dispose);
    var changes = 0;
    coordinator.onChanged = () => changes++;

    coordinator.rememberPosition('fixed:recommended', 1);
    coordinator.queueFeedPersistence(primaryCategoryIndex: 0);
    await coordinator.flushFeedWrites();
    expect(coordinator.preferenceError, isNotNull);

    coordinator.rememberPosition('fixed:recommended', 2);
    coordinator.queueFeedPersistence(primaryCategoryIndex: 0);
    await coordinator.flushFeedWrites();

    expect(repository.savedPositions, [1, 2]);
    expect(coordinator.preferenceError, isNull);
    expect(changes, 2);
  });

  test('serial channel writes recover after an unexpected failure', () async {
    final repository = _FlakyChannelPreferenceRepository();
    final coordinator = PaperFeedPreferenceCoordinator(
      channelPreferenceRepository: repository,
    );
    addTearDown(coordinator.dispose);
    const channel = UserPaperChannel(
      kind: PaperChannelKind.subject,
      id: 'cs.CL',
      displayName: '计算与语言',
    );

    coordinator.replaceUserChannels(const [channel, channel]);
    coordinator.selectChannel(channel.storageKey);
    coordinator.queueChannelPersistence();
    await coordinator.flushChannelWrites();
    expect(coordinator.channelPreferenceError, isNotNull);

    coordinator.queueChannelPersistence();
    await coordinator.flushChannelWrites();

    expect(repository.saveCalls, 2);
    expect(repository.savedChannelCounts, [1, 1]);
    expect(repository.selectedKeys, ['subject:cs.CL', 'subject:cs.CL']);
    expect(coordinator.channelPreferenceError, isNull);
  });

  test('pending preference load cannot commit after dispose', () async {
    final repository = _PendingPaperPreferenceRepository();
    final coordinator = PaperFeedPreferenceCoordinator(
      preferenceRepository: repository,
    );
    final initialization = coordinator.initializeFeedPreferences();

    coordinator.dispose();
    repository.complete(
      PaperPreferences(positions: const {'fixed:recommended': 4}),
    );

    await expectLater(initialization, completes);
    expect(coordinator.positionFor('fixed:recommended'), 0);
  });

  test('replays and persists feed changes made during a pending load',
      () async {
    final repository = _PendingPaperPreferenceRepository();
    final coordinator = PaperFeedPreferenceCoordinator(
      preferenceRepository: repository,
    );
    addTearDown(coordinator.dispose);

    final initialization = coordinator.initializeFeedPreferences();
    coordinator.rememberPosition('fixed:latest', 4);
    coordinator.selectTimeRange(
      'fixed:recommended',
      const PaperTimeRange.last30Days(),
    );
    coordinator.queueFeedPersistence(primaryCategoryIndex: 1);
    await Future<void>.delayed(Duration.zero);
    final savedBeforeLoad = repository.savedPreferences.length;

    repository.complete(
      PaperPreferences(
        positions: const {
          'fixed:recommended': 3,
          'fixed:following': 7,
        },
        timeRanges: const {'fixed:recommended': 'last-7-days'},
        primaryCategoryIndex: 2,
      ),
    );
    await initialization;
    await coordinator.flushFeedWrites();

    expect(savedBeforeLoad, 0);
    expect(coordinator.positionFor('fixed:recommended'), 0);
    expect(coordinator.positionFor('fixed:latest'), 4);
    expect(coordinator.positionFor('fixed:following'), 7);
    expect(
      coordinator.timeRangeFor('fixed:recommended').storageKey,
      const PaperTimeRange.last30Days().storageKey,
    );
    expect(coordinator.legacyPrimaryIndex, 1);
    expect(repository.savedPreferences, hasLength(1));
    expect(repository.savedPreferences.single.positions, {
      'fixed:recommended': 0,
      'fixed:following': 7,
      'fixed:latest': 4,
    });
    expect(repository.savedPreferences.single.primaryCategoryIndex, 1);
  });

  test('replays and persists channel changes made during a pending load',
      () async {
    final repository = _PendingChannelPreferenceRepository();
    final coordinator = PaperFeedPreferenceCoordinator(
      channelPreferenceRepository: repository,
    );
    addTearDown(coordinator.dispose);
    const newChannel = UserPaperChannel(
      kind: PaperChannelKind.subject,
      id: 'cs.CL',
      displayName: '计算与语言',
    );

    final initialization = coordinator.initializeChannelPreferences();
    coordinator.replaceUserChannels(const [newChannel]);
    coordinator.selectChannel(newChannel.storageKey);
    coordinator.queueChannelPersistence();
    await Future<void>.delayed(Duration.zero);
    final savedBeforeLoad = repository.savedPreferences.length;

    repository.complete(
      PaperChannelPreferences(
        userChannels: const [
          UserPaperChannel(
            kind: PaperChannelKind.subject,
            id: 'cs.AI',
            displayName: '人工智能',
          ),
        ],
        selectedChannelKey: 'subject:cs.AI',
      ),
    );
    await initialization;
    await coordinator.flushChannelWrites();

    expect(savedBeforeLoad, 0);
    expect(coordinator.userChannels, const [newChannel]);
    expect(coordinator.selectedChannelKey, newChannel.storageKey);
    expect(repository.savedPreferences, hasLength(1));
    expect(repository.savedPreferences.single.userChannels, const [newChannel]);
    expect(
      repository.savedPreferences.single.selectedChannelKey,
      newChannel.storageKey,
    );
  });
}

class _SeedPaperPreferenceRepository implements PaperPreferenceRepository {
  @override
  Future<PaperPreferences> load() async => PaperPreferences(
        positions: const {'fixed:recommended': 3},
        timeRanges: const {'fixed:recommended': 'last-7-days'},
        primaryCategoryIndex: 2,
      );

  @override
  Future<void> save(PaperPreferences preferences) async {}
}

class _SeedChannelPreferenceRepository
    implements PaperChannelPreferenceRepository {
  @override
  Future<PaperChannelPreferences> load() async => PaperChannelPreferences(
        userChannels: const [
          UserPaperChannel(
            kind: PaperChannelKind.subject,
            id: 'cs.AI',
            displayName: '人工智能',
          ),
        ],
        selectedChannelKey: 'subject:cs.AI',
      );

  @override
  Future<void> save(PaperChannelPreferences preferences) async {}
}

class _FlakyPaperPreferenceRepository implements PaperPreferenceRepository {
  final List<int> savedPositions = [];

  @override
  Future<PaperPreferences> load() async => PaperPreferences();

  @override
  Future<void> save(PaperPreferences preferences) async {
    savedPositions.add(preferences.positions['fixed:recommended']!);
    if (savedPositions.length == 1) throw StateError('disk unavailable');
  }
}

class _PendingPaperPreferenceRepository implements PaperPreferenceRepository {
  final _load = Completer<PaperPreferences>();
  final List<PaperPreferences> savedPreferences = [];

  void complete(PaperPreferences preferences) => _load.complete(preferences);

  @override
  Future<PaperPreferences> load() => _load.future;

  @override
  Future<void> save(PaperPreferences preferences) async {
    savedPreferences.add(preferences);
  }
}

class _PendingChannelPreferenceRepository
    implements PaperChannelPreferenceRepository {
  final _load = Completer<PaperChannelPreferences>();
  final List<PaperChannelPreferences> savedPreferences = [];

  void complete(PaperChannelPreferences preferences) =>
      _load.complete(preferences);

  @override
  Future<PaperChannelPreferences> load() => _load.future;

  @override
  Future<void> save(PaperChannelPreferences preferences) async {
    savedPreferences.add(preferences);
  }
}

class _FlakyChannelPreferenceRepository
    implements PaperChannelPreferenceRepository {
  int saveCalls = 0;
  final List<int> savedChannelCounts = [];
  final List<String?> selectedKeys = [];

  @override
  Future<PaperChannelPreferences> load() async => PaperChannelPreferences();

  @override
  Future<void> save(PaperChannelPreferences preferences) async {
    saveCalls++;
    savedChannelCounts.add(preferences.userChannels.length);
    selectedKeys.add(preferences.selectedChannelKey);
    if (saveCalls == 1) throw StateError('disk unavailable');
  }
}
