import 'package:flutter/foundation.dart';

import '../domain/paper_comment_repository.dart';

enum PaperCommentSort { newest, hottest }

class PaperCommentController extends ChangeNotifier {
  PaperCommentController({PaperCommentRepository? repository})
      : _repository = repository;

  final PaperCommentRepository? _repository;
  final Map<String, List<PaperCommentRecord>> _commentsByPaper = {};
  final Map<String, PaperCommentSort> _sortByPaper = {};
  final Set<String> _loadedPaperIds = {};
  final Map<String, Future<void>> _loadOperations = {};
  Future<void> _writeQueue = Future.value();
  String? _persistenceError;
  bool _disposed = false;

  String? get persistenceError => _persistenceError;

  List<PaperCommentRecord> commentsFor(String paperId) {
    final comments = List<PaperCommentRecord>.of(
      _commentsByPaper[paperId] ?? const [],
    );
    if (sortFor(paperId) == PaperCommentSort.hottest) {
      final originalOrder = <String, int>{
        for (var index = 0; index < comments.length; index++)
          comments[index].id: index,
      };
      comments.sort((left, right) {
        final byLikes = right.likes.compareTo(left.likes);
        if (byLikes != 0) return byLikes;
        return originalOrder[left.id]!.compareTo(originalOrder[right.id]!);
      });
    }
    return List.unmodifiable(comments);
  }

  PaperCommentSort sortFor(String paperId) =>
      _sortByPaper[paperId] ?? PaperCommentSort.newest;

  void setSort(String paperId, PaperCommentSort sort) {
    if (sortFor(paperId) == sort) return;
    _sortByPaper[paperId] = sort;
    _notifyListeners();
  }

  int commentCount(String paperId) => commentsFor(paperId).length;

  int rootCommentCount(String paperId) =>
      commentsFor(paperId).where((comment) => comment.parentId == null).length;

  bool isLoading(String paperId) => _loadOperations.containsKey(paperId);

  Future<void> initialize(Iterable<String> paperIds) async {
    await Future.wait(paperIds.map(loadPaper));
  }

  Future<void> loadPaper(String paperId) {
    if (_loadedPaperIds.contains(paperId)) return Future.value();
    final existing = _loadOperations[paperId];
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = Future<void>.sync(() => _loadPaper(paperId)).whenComplete(() {
      if (identical(_loadOperations[paperId], operation)) {
        _loadOperations.remove(paperId);
        _notifyListeners();
      }
    });
    _loadOperations[paperId] = operation;
    _notifyListeners();
    return operation;
  }

  Future<void> _loadPaper(String paperId) async {
    try {
      final repository = _repository;
      final snapshot = repository == null
          ? const PaperCommentSnapshot(comments: [], hasStoredValue: false)
          : await repository.load(paperId);
      _commentsByPaper[paperId] = snapshot.comments
          .where((comment) => !comment.id.startsWith('seed-'))
          .toList(growable: true);
      _loadedPaperIds.add(paperId);
      _persistenceError = null;
      if (repository != null &&
          _commentsByPaper[paperId]!.length != snapshot.comments.length) {
        await repository.save(paperId, _rawCommentsFor(paperId));
      }
    } on PaperCommentPersistenceException catch (error) {
      _persistenceError = error.message;
    }
    _notifyListeners();
  }

  Future<void> addComment(
    String paperId,
    String body, {
    String? parentId,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await loadPaper(paperId);
    final comments = _commentsByPaper.putIfAbsent(paperId, () => []);
    comments.insert(
      0,
      PaperCommentRecord(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        paperId: paperId,
        name: 'Alex Chen',
        initials: 'AC',
        time: '刚刚',
        location: '北京',
        body: text,
        likes: 0,
        parentId: parentId,
        isLocalUser: true,
      ),
    );
    _notifyListeners();
    _queuePersistence(paperId);
  }

  void toggleLike(String paperId, String commentId) {
    final comments = _commentsByPaper[paperId];
    if (comments == null) return;
    final index = comments.indexWhere((comment) => comment.id == commentId);
    if (index < 0) return;
    final current = comments[index];
    comments[index] = PaperCommentRecord(
      id: current.id,
      paperId: current.paperId,
      name: current.name,
      initials: current.initials,
      time: current.time,
      location: current.location,
      body: current.body,
      likes: current.likes + (current.likedByLocalUser ? -1 : 1),
      parentId: current.parentId,
      isLocalUser: current.isLocalUser,
      likedByLocalUser: !current.likedByLocalUser,
    );
    _notifyListeners();
    _queuePersistence(paperId);
  }

  void deleteComment(String paperId, String commentId) {
    final comments = _commentsByPaper[paperId];
    if (comments == null) return;
    final canDelete = comments.any(
      (comment) => comment.id == commentId && comment.isLocalUser,
    );
    if (!canDelete) return;
    comments.removeWhere(
      (comment) => comment.id == commentId || comment.parentId == commentId,
    );
    _notifyListeners();
    _queuePersistence(paperId);
  }

  Future<void> flushPendingWrites() => _writeQueue;

  void _queuePersistence(String paperId) {
    final repository = _repository;
    if (repository == null) return;
    final snapshot = _rawCommentsFor(paperId);
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(paperId, snapshot);
        _persistenceError = null;
      } on PaperCommentPersistenceException catch (error) {
        _persistenceError = error.message;
      }
      _notifyListeners();
    });
  }

  List<PaperCommentRecord> _rawCommentsFor(String paperId) =>
      List.unmodifiable(_commentsByPaper[paperId] ?? const []);

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
