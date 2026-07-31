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
        _repository = repository;

  final Set<String> _likedPaperIds = {};
  final Set<String> _savedPaperIds;
  final Set<String> _followedPaperIds;
  final Map<String, int> _shareCountDeltas = {};
  final PaperInteractionRepository? _repository;
  Future<void> _writeQueue = Future.value();
  String? _persistenceError;

  Set<String> get followedPaperIds => Set.unmodifiable(_followedPaperIds);
  String? get persistenceError => _persistenceError;
  int shareCountDelta(String paperId) => _shareCountDeltas[paperId] ?? 0;

  bool isLiked(String paperId) => _likedPaperIds.contains(paperId);
  bool isSaved(String paperId) => _savedPaperIds.contains(paperId);
  bool isFollowed(String paperId) => _followedPaperIds.contains(paperId);

  bool isAuthorFollowed(PaperRecord paper) =>
      isFollowed(paper.authorKey) || isFollowed(paper.id);

  Future<void> initialize() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final snapshot = await repository.load();
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
      _persistenceError = null;
    } on PaperInteractionPersistenceException catch (error) {
      _persistenceError = error.message;
    }
    notifyListeners();
  }

  void toggleLike(String paperId) {
    _toggleMembership(_likedPaperIds, paperId);
  }

  void toggleSave(String paperId) {
    _toggleMembership(_savedPaperIds, paperId);
  }

  void toggleFollow(String paperId) {
    _toggleMembership(_followedPaperIds, paperId);
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
    _shareCountDeltas.update(paperId, (value) => value + 1, ifAbsent: () => 1);
    notifyListeners();
    _queuePersistence();
  }

  void _toggleMembership(Set<String> values, String paperId) {
    if (!values.remove(paperId)) values.add(paperId);
    notifyListeners();
    _queuePersistence();
  }

  Future<void> flushPendingWrites() => _writeQueue;

  void _queuePersistence() {
    final repository = _repository;
    if (repository == null) return;
    final snapshot = PaperInteractionSnapshot(
      likedPaperIds: _likedPaperIds,
      savedPaperIds: _savedPaperIds,
      followedPaperIds: _followedPaperIds,
      shareCountDeltas: _shareCountDeltas,
    );
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(snapshot);
        _persistenceError = null;
      } on PaperInteractionPersistenceException catch (error) {
        _persistenceError = error.message;
      }
      notifyListeners();
    });
  }
}
