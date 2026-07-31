import 'package:flutter/foundation.dart';

import '../domain/paper.dart';
import '../domain/paper_feed_filter.dart';
import '../domain/paper_preference_repository.dart';
import '../domain/paper_repository.dart';

class PaperFeedController extends ChangeNotifier {
  PaperFeedController(
    PaperRepository repository, {
    PaperPreferenceRepository? preferenceRepository,
  }) : this.fromPapers(
          repository.getAll(),
          preferenceRepository: preferenceRepository,
        );

  PaperFeedController.fromPapers(
    Iterable<PaperRecord> papers, {
    PaperPreferenceRepository? preferenceRepository,
  })  : _allPapers = List.unmodifiable(papers),
        _preferenceRepository = preferenceRepository {
    _refreshVisiblePapers();
  }

  static const primaryCategories = ['推荐', '关注', '最新'];
  static const defaultTopics = [
    '全部',
    'LLM',
    'NLP',
    'CV',
    'Agent',
    '多模态',
    'Systems',
    'Mathematics',
    'Biology',
  ];

  final List<PaperRecord> _allPapers;
  late List<PaperRecord> _visiblePapers;
  Set<String> _followedPaperIds = {};
  final PaperPreferenceRepository? _preferenceRepository;
  Future<void> _preferenceWriteQueue = Future.value();
  String? _preferenceError;
  final Map<String, int> _positions = {};
  List<String> _extraCategories = [];
  int _primaryCategoryIndex = 0;
  int _topicIndex = 0;
  int _currentPaperIndex = 0;
  bool _gridMode = false;

  List<PaperRecord> get papers => _visiblePapers;
  List<PaperRecord> get allPapers => _allPapers;
  List<String> get extraCategories => List.unmodifiable(_extraCategories);
  List<String> get topics => [...defaultTopics, ..._extraCategories];
  int get primaryCategoryIndex => _primaryCategoryIndex;
  int get topicIndex => _topicIndex;
  int get categoryIndex => _topicIndex;
  int get currentPaperIndex => _currentPaperIndex;
  bool get gridMode => _gridMode;
  String? get preferenceError => _preferenceError;

  Future<void> initializePreferences() async {
    final repository = _preferenceRepository;
    if (repository == null) return;
    try {
      final preferences = await repository.load();
      _extraCategories = List.of(preferences.extraTopics);
      _preferenceError = null;
      _restorePosition();
    } on PaperPreferencePersistenceException catch (error) {
      _preferenceError = error.message;
    }
    notifyListeners();
  }

  void toggleGridMode() {
    _gridMode = !_gridMode;
    notifyListeners();
  }

  void openPaper(int index) {
    if (index < 0 || index >= _visiblePapers.length) return;
    _currentPaperIndex = index;
    _gridMode = false;
    notifyListeners();
  }

  void openPaperById(String paperId) {
    final exists = _allPapers.any((paper) => paper.id == paperId);
    if (!exists) return;
    _rememberPosition();
    _primaryCategoryIndex = PaperFeedMode.recommended.index;
    _topicIndex = 0;
    _refreshVisiblePapers();
    _currentPaperIndex =
        _visiblePapers.indexWhere((paper) => paper.id == paperId);
    _positions[_filterKey] = _currentPaperIndex;
    _gridMode = false;
    notifyListeners();
  }

  void selectPaper(int index) {
    if (index == _currentPaperIndex ||
        index < 0 ||
        index >= _visiblePapers.length) {
      return;
    }
    _currentPaperIndex = index;
    _positions[_filterKey] = index;
    notifyListeners();
  }

  void selectPrimaryCategory(int index) {
    if (index == _primaryCategoryIndex ||
        index < 0 ||
        index >= primaryCategories.length) {
      return;
    }
    _rememberPosition();
    _primaryCategoryIndex = index;
    _restorePosition();
    notifyListeners();
  }

  void selectTopic(int index) {
    if (index == _topicIndex || index < 0 || index >= topics.length) {
      return;
    }
    _rememberPosition();
    _topicIndex = index;
    _restorePosition();
    notifyListeners();
  }

  void selectTopicByName(String topic) {
    final normalized = topic.trim();
    if (normalized.isEmpty) return;
    final existingIndex = topics.indexOf(normalized);
    if (existingIndex >= 0) {
      selectTopic(existingIndex);
      return;
    }

    _rememberPosition();
    _extraCategories = [..._extraCategories, normalized];
    _topicIndex = topics.length - 1;
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
  }

  void selectCategory(int index) => selectTopic(index);

  void setExtraCategories(List<String> categories) {
    _rememberPosition();
    _extraCategories = List.of(categories);
    if (_topicIndex >= topics.length) _topicIndex = 0;
    _restorePosition();
    notifyListeners();
    _queuePreferencePersistence();
  }

  void setFollowedPaperIds(Iterable<String> paperIds) {
    final next = paperIds.toSet();
    if (setEquals(next, _followedPaperIds)) return;
    _followedPaperIds = next;
    if (_primaryCategoryIndex != PaperFeedMode.following.index) return;
    _rememberPosition();
    _restorePosition();
    notifyListeners();
  }

  void _rememberPosition() {
    if (_visiblePapers.isNotEmpty) {
      _positions[_filterKey] = _currentPaperIndex;
    }
  }

  void _restorePosition() {
    _refreshVisiblePapers();
    if (_visiblePapers.isEmpty) {
      _currentPaperIndex = 0;
      return;
    }
    _currentPaperIndex =
        (_positions[_filterKey] ?? 0).clamp(0, _visiblePapers.length - 1);
  }

  void _refreshVisiblePapers() {
    _visiblePapers = PaperFeedFilter.apply(
      papers: _allPapers,
      mode: PaperFeedMode.values[_primaryCategoryIndex],
      topic: topics[_topicIndex],
      followedPaperIds: _followedPaperIds,
    );
  }

  String get _filterKey => _primaryCategoryIndex == 0
      ? '$_primaryCategoryIndex:$_topicIndex'
      : '$_primaryCategoryIndex';

  Future<void> flushPreferenceWrites() => _preferenceWriteQueue;

  void _queuePreferencePersistence() {
    final repository = _preferenceRepository;
    if (repository == null) return;
    final preferences = PaperPreferences(extraTopics: _extraCategories);
    _preferenceWriteQueue = _preferenceWriteQueue.then((_) async {
      try {
        await repository.save(preferences);
        _preferenceError = null;
      } on PaperPreferencePersistenceException catch (error) {
        _preferenceError = error.message;
      }
      notifyListeners();
    });
  }
}
