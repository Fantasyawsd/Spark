import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/paper.dart';
import '../domain/paper_interaction_repository.dart';

class PaperInteractionController extends ChangeNotifier {
  PaperInteractionController({
    Iterable<String> initiallySaved = const [],
    Iterable<String> initiallyFollowed = const [],
    PaperInteractionRepository? repository,
  })  : _savedPaperIds = {...initiallySaved},
        _followedPaperIds = {...initiallyFollowed},
        _repository = repository {
    _committedSnapshot = _currentSnapshot();
    _initialized = repository == null;
  }

  final Set<String> _likedPaperIds = {};
  final Set<String> _savedPaperIds;
  final Set<String> _followedPaperIds;
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

  Set<String> get followedPaperIds => Set.unmodifiable(_followedPaperIds);
  String? get persistenceError => _persistenceError;
  int get errorRevision => _errorRevision;
  bool get initialized => _initialized;
  int shareCountDelta(String paperId) => _shareCountDeltas[paperId] ?? 0;

  bool isLiked(String paperId) => _likedPaperIds.contains(paperId);
  bool isSaved(String paperId) => _savedPaperIds.contains(paperId);
  bool isFollowed(String paperId) => _followedPaperIds.contains(paperId);

  bool isAuthorFollowed(PaperRecord paper) =>
      isFollowed(paper.authorKey) || isFollowed(paper.id);

  Future<void> initialize() {
    if (_initialized) return Future.value();
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
    } on PaperInteractionPersistenceException catch (error) {
      _persistenceError = error.message;
      _errorRevision++;
    }
    _notifyListeners();
  }

  void toggleLike(String paperId) {
    _mutate(_InteractionMutation(_InteractionMutationType.like, paperId));
  }

  void toggleSave(String paperId) {
    _mutate(_InteractionMutation(_InteractionMutationType.save, paperId));
  }

  void toggleFollow(String paperId) {
    _mutate(_InteractionMutation(_InteractionMutationType.follow, paperId));
  }

  void toggleFollowAuthor(PaperRecord paper) {
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
      case _InteractionMutationType.save:
        _toggleMembership(_savedPaperIds, mutation.paperId);
      case _InteractionMutationType.follow:
        _toggleMembership(_followedPaperIds, mutation.paperId);
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

  Future<void> flushPendingWrites() async {
    await _initialization;
    await _writeQueue;
  }

  void _queuePersistence() {
    final repository = _repository;
    if (repository == null) return;
    final revision = ++_revision;
    final snapshot = _currentSnapshot();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(snapshot);
        _committedSnapshot = snapshot;
        if (revision == _revision) _persistenceError = null;
      } on PaperInteractionPersistenceException catch (error) {
        if (revision == _revision) {
          _restore(_committedSnapshot);
          _persistenceError = error.message;
          _errorRevision++;
        }
      }
      _notifyListeners();
    });
  }

  PaperInteractionSnapshot _currentSnapshot() => PaperInteractionSnapshot(
        likedPaperIds: _likedPaperIds,
        savedPaperIds: _savedPaperIds,
        followedPaperIds: _followedPaperIds,
        shareCountDeltas: _shareCountDeltas,
      );

  void _restore(PaperInteractionSnapshot snapshot) {
    _likedPaperIds
      ..clear()
      ..addAll(snapshot.likedPaperIds);
    _savedPaperIds
      ..clear()
      ..addAll(snapshot.savedPaperIds);
    _followedPaperIds
      ..clear()
      ..addAll(snapshot.followedPaperIds);
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
    super.dispose();
  }
}

enum _InteractionMutationType { like, save, follow, share }

class _InteractionMutation {
  const _InteractionMutation(this.type, this.paperId);

  final _InteractionMutationType type;
  final String paperId;
}
