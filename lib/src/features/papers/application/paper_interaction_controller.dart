import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/favorite_group.dart';
import '../domain/paper.dart';
import '../domain/paper_interaction_repository.dart';

class PaperInteractionController extends ChangeNotifier {
  PaperInteractionController({
    Iterable<String> initiallySaved = const [],
    Iterable<String> initiallyFollowed = const [],
    PaperInteractionRepository? repository,
  })  : _followedPaperIds = ValueNotifier<Set<String>>(
          Set<String>.unmodifiable(initiallyFollowed),
        ),
        _repository = repository {
    _favoriteGroups[defaultFavoriteGroupId] =
        const FavoriteGroup.defaultGroup();
    _favoritePaperIdsByGroup[defaultFavoriteGroupId] = {...initiallySaved};
    _committedSnapshot = _currentSnapshot();
    _initialized = repository == null;
  }

  final Set<String> _likedPaperIds = {};
  final Map<String, FavoriteGroup> _favoriteGroups = {};
  final Map<String, Set<String>> _favoritePaperIdsByGroup = {};
  final ValueNotifier<Set<String>> _followedPaperIds;
  final Map<String, int> _shareCountDeltas = {};
  final PaperInteractionRepository? _repository;
  final List<_InteractionMutation> _pendingMutations = [];
  Future<void> _writeQueue = Future.value();
  Future<void>? _initialization;
  late PaperInteractionSnapshot _committedSnapshot;
  late bool _initialized;
  int _revision = 0;
  int _errorRevision = 0;
  String? _persistenceError;
  bool _disposed = false;

  Set<String> get followedPaperIds => _followedPaperIds.value;
  ValueListenable<Set<String>> get followedPaperIdsListenable =>
      _followedPaperIds;
  List<FavoriteGroup> get favoriteGroups =>
      List.unmodifiable(_favoriteGroups.values);
  Set<String> get savedPaperIds => Set.unmodifiable(
        _favoritePaperIdsByGroup.values.expand((paperIds) => paperIds),
      );
  String? get persistenceError => _persistenceError;
  int get errorRevision => _errorRevision;
  bool get initialized => _initialized;
  int shareCountDelta(String paperId) => _shareCountDeltas[paperId] ?? 0;

  bool isLiked(String paperId) => _likedPaperIds.contains(paperId);
  bool isSaved(String paperId) => _favoritePaperIdsByGroup.values.any(
        (paperIds) => paperIds.contains(paperId),
      );
  bool isSavedInGroup(String paperId, String groupId) =>
      _favoritePaperIdsByGroup[groupId]?.contains(paperId) ?? false;
  bool isFollowed(String paperId) => _followedPaperIds.value.contains(paperId);

  Set<String> favoriteGroupIdsForPaper(String paperId) => Set.unmodifiable(
        _favoritePaperIdsByGroup.entries
            .where((entry) => entry.value.contains(paperId))
            .map((entry) => entry.key),
      );
  Set<String> favoritePaperIds(String groupId) =>
      Set.unmodifiable(_favoritePaperIdsByGroup[groupId] ?? const {});

  bool isAuthorFollowed(Paper paper) =>
      isFollowed(paper.authorKey) || isFollowed(paper.id);

  Future<void> initialize() {
    if (_disposed || _initialized) return Future.value();
    final existing = _initialization;
    if (existing != null) return existing;
    final repository = _repository;
    if (repository == null) {
      _initialized = true;
      return Future.value();
    }
    late final Future<void> operation;
    operation = _initialize(repository).whenComplete(() {
      if (identical(_initialization, operation)) _initialization = null;
    });
    _initialization = operation;
    return operation;
  }

  Future<void> _initialize(PaperInteractionRepository repository) async {
    try {
      final snapshot = await repository.load();
      if (_disposed) return;
      _restore(snapshot);
      _committedSnapshot = snapshot;
      final pendingMutations = List.of(_pendingMutations);
      _pendingMutations.clear();
      for (final mutation in pendingMutations) {
        _applyMutation(mutation);
      }
      _initialized = true;
      _persistenceError = null;
      if (pendingMutations.isNotEmpty) _queuePersistence();
    } on PaperInteractionPersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperInteractionsLoad,
        error,
        stackTrace,
      );
      if (_disposed) return;
      _persistenceError = error.message;
      _errorRevision++;
    } on Object catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperInteractionsLoad,
        error,
        stackTrace,
      );
      if (_disposed) return;
      _persistenceError = '论文交互状态读取失败，请稍后重试。';
      _errorRevision++;
    }
    _notifyListeners();
  }

  void toggleLike(String paperId) {
    _mutate(_InteractionMutation(_InteractionMutationType.like, paperId));
  }

  void toggleSave(String paperId) {
    _mutate(
      _InteractionMutation.favoriteMembership(
        paperId: paperId,
        groupId: defaultFavoriteGroupId,
        selected: !isSavedInGroup(paperId, defaultFavoriteGroupId),
      ),
    );
  }

  void setFavoriteMembership({
    required String paperId,
    required String groupId,
    required bool selected,
  }) {
    if (!_favoriteGroups.containsKey(groupId)) {
      throw ArgumentError.value(groupId, 'groupId', '收藏分组不存在');
    }
    if (isSavedInGroup(paperId, groupId) == selected) return;
    _mutate(
      _InteractionMutation.favoriteMembership(
        paperId: paperId,
        groupId: groupId,
        selected: selected,
      ),
    );
  }

  String createFavoriteGroup(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', '收藏分组名称不能为空');
    }
    for (final group in _favoriteGroups.values) {
      if (group.name.toLowerCase() == normalizedName.toLowerCase()) {
        return group.id;
      }
    }
    final id = 'favorite-${DateTime.now().microsecondsSinceEpoch}';
    _mutate(
      _InteractionMutation.createFavoriteGroup(
        FavoriteGroup(id: id, name: normalizedName),
      ),
    );
    return id;
  }

  void renameFavoriteGroup(String groupId, String name) {
    if (groupId == defaultFavoriteGroupId) return;
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || !_favoriteGroups.containsKey(groupId)) {
      return;
    }
    if (_favoriteGroups.values.any(
      (group) =>
          group.id != groupId &&
          group.name.toLowerCase() == normalizedName.toLowerCase(),
    )) {
      return;
    }
    _mutate(
      _InteractionMutation.renameFavoriteGroup(
        groupId: groupId,
        name: normalizedName,
      ),
    );
  }

  void deleteFavoriteGroup(String groupId) {
    if (groupId == defaultFavoriteGroupId ||
        !_favoriteGroups.containsKey(groupId)) {
      return;
    }
    _mutate(_InteractionMutation.deleteFavoriteGroup(groupId));
  }

  void toggleFollow(String paperId) {
    _mutate(_InteractionMutation(_InteractionMutationType.follow, paperId));
  }

  void toggleFollowAuthor(Paper paper) {
    if (isFollowed(paper.authorKey)) {
      toggleFollow(paper.authorKey);
    } else if (isFollowed(paper.id)) {
      toggleFollow(paper.id);
    } else {
      toggleFollow(paper.authorKey);
    }
  }

  void recordShare(String paperId) {
    _mutate(_InteractionMutation(_InteractionMutationType.share, paperId));
  }

  void _mutate(_InteractionMutation mutation) {
    if (_disposed) return;
    _applyMutation(mutation);
    if (_initialized) {
      _persistenceError = null;
    } else {
      _pendingMutations.add(mutation);
    }
    _notifyListeners();
    if (_initialized) {
      _queuePersistence();
    } else {
      unawaited(initialize());
    }
  }

  void _applyMutation(_InteractionMutation mutation) {
    switch (mutation.type) {
      case _InteractionMutationType.like:
        _toggleMembership(_likedPaperIds, mutation.paperId);
      case _InteractionMutationType.favoriteMembership:
        final paperIds = _favoritePaperIdsByGroup[mutation.groupId];
        if (paperIds == null) return;
        if (mutation.selected!) {
          paperIds.add(mutation.paperId);
        } else {
          paperIds.remove(mutation.paperId);
        }
      case _InteractionMutationType.createFavoriteGroup:
        final group = mutation.group!;
        _favoriteGroups[group.id] = group;
        _favoritePaperIdsByGroup.putIfAbsent(group.id, () => {});
      case _InteractionMutationType.renameFavoriteGroup:
        final groupId = mutation.groupId!;
        if (!_favoriteGroups.containsKey(groupId)) return;
        _favoriteGroups[groupId] = FavoriteGroup(
          id: groupId,
          name: mutation.name!,
        );
      case _InteractionMutationType.deleteFavoriteGroup:
        _favoriteGroups.remove(mutation.groupId);
        _favoritePaperIdsByGroup.remove(mutation.groupId);
      case _InteractionMutationType.follow:
        final followedPaperIds = {..._followedPaperIds.value};
        _toggleMembership(followedPaperIds, mutation.paperId);
        _replaceFollowedPaperIds(followedPaperIds);
      case _InteractionMutationType.share:
        _shareCountDeltas.update(
          mutation.paperId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
    }
  }

  void _toggleMembership(Set<String> values, String paperId) {
    if (!values.remove(paperId)) values.add(paperId);
  }

  void _replaceFollowedPaperIds(Iterable<String> paperIds) {
    final next = Set<String>.unmodifiable(paperIds);
    if (setEquals(next, _followedPaperIds.value)) return;
    _followedPaperIds.value = next;
  }

  Future<void> flushPendingWrites() async {
    await _initialization;
    await _writeQueue;
  }

  Future<void> reload() async {
    await flushPendingWrites();
    if (_disposed) return;
    _pendingMutations.clear();
    _initialized = false;
    final empty = PaperInteractionSnapshot();
    _restore(empty);
    _committedSnapshot = empty;
    final repository = _repository;
    if (repository == null) {
      _initialized = true;
      _persistenceError = null;
      _notifyListeners();
      return;
    }
    await _initialize(repository);
  }

  void _queuePersistence() {
    final repository = _repository;
    if (repository == null) return;
    final revision = ++_revision;
    final snapshot = _currentSnapshot();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(snapshot);
        if (_disposed) return;
        _committedSnapshot = snapshot;
        if (revision == _revision) _persistenceError = null;
      } on PaperInteractionPersistenceException catch (error, stackTrace) {
        _reportPersistenceFailure(
          SparkDiagnosticOperation.paperInteractionsSave,
          error,
          stackTrace,
        );
        if (!_disposed && revision == _revision) {
          _restore(_committedSnapshot);
          _persistenceError = error.message;
          _errorRevision++;
        }
      } on Object catch (error, stackTrace) {
        _reportPersistenceFailure(
          SparkDiagnosticOperation.paperInteractionsSave,
          error,
          stackTrace,
        );
        if (!_disposed && revision == _revision) {
          _restore(_committedSnapshot);
          _persistenceError = '论文交互状态保存失败，请稍后重试。';
          _errorRevision++;
        }
      }
      _notifyListeners();
    });
  }

  PaperInteractionSnapshot _currentSnapshot() => PaperInteractionSnapshot(
        likedPaperIds: _likedPaperIds,
        favoriteGroups: _favoriteGroups.values,
        favoritePaperIdsByGroup: _favoritePaperIdsByGroup,
        followedPaperIds: _followedPaperIds.value,
        shareCountDeltas: _shareCountDeltas,
      );

  static void _reportPersistenceFailure(
    SparkDiagnosticOperation operation,
    Object error,
    StackTrace stackTrace,
  ) {
    SparkDiagnostics.reportUnexpected(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      severity: SparkDiagnosticSeverity.warning,
    );
  }

  void _restore(PaperInteractionSnapshot snapshot) {
    _likedPaperIds
      ..clear()
      ..addAll(snapshot.likedPaperIds);
    _favoriteGroups
      ..clear()
      ..addEntries(
        snapshot.favoriteGroups.map((group) => MapEntry(group.id, group)),
      );
    _favoritePaperIdsByGroup
      ..clear()
      ..addEntries(
        snapshot.favoritePaperIdsByGroup.entries.map(
          (entry) => MapEntry(entry.key, {...entry.value}),
        ),
      );
    _replaceFollowedPaperIds(snapshot.followedPaperIds);
    _shareCountDeltas
      ..clear()
      ..addAll(snapshot.shareCountDeltas);
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _followedPaperIds.dispose();
    super.dispose();
  }
}

enum _InteractionMutationType {
  like,
  favoriteMembership,
  createFavoriteGroup,
  renameFavoriteGroup,
  deleteFavoriteGroup,
  follow,
  share,
}

class _InteractionMutation {
  const _InteractionMutation(this.type, this.paperId)
      : groupId = null,
        selected = null,
        group = null,
        name = null;

  const _InteractionMutation.favoriteMembership({
    required this.paperId,
    required this.groupId,
    required this.selected,
  })  : type = _InteractionMutationType.favoriteMembership,
        group = null,
        name = null;

  const _InteractionMutation.createFavoriteGroup(this.group)
      : type = _InteractionMutationType.createFavoriteGroup,
        paperId = '',
        groupId = null,
        selected = null,
        name = null;

  const _InteractionMutation.renameFavoriteGroup({
    required this.groupId,
    required this.name,
  })  : type = _InteractionMutationType.renameFavoriteGroup,
        paperId = '',
        selected = null,
        group = null;

  const _InteractionMutation.deleteFavoriteGroup(this.groupId)
      : type = _InteractionMutationType.deleteFavoriteGroup,
        paperId = '',
        selected = null,
        group = null,
        name = null;

  final _InteractionMutationType type;
  final String paperId;
  final String? groupId;
  final bool? selected;
  final FavoriteGroup? group;
  final String? name;
}
