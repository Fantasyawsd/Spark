import 'package:flutter/foundation.dart';

import '../domain/paper.dart';
import '../domain/paper_repository.dart';

class PaperController extends ChangeNotifier {
  PaperController(PaperRepository repository) : _papers = repository.getAll() {
    if (_papers.isNotEmpty) _savedPaperIds.add(_papers.first.id);
  }

  static const baseCategories = ['推荐', '关注', 'NLP', 'CV', 'ML'];

  final List<PaperRecord> _papers;
  final Set<String> _likedPaperIds = {};
  final Set<String> _savedPaperIds = {};
  List<String> _extraCategories = [];
  int _categoryIndex = 0;
  int _currentPaperIndex = 0;
  bool _gridMode = false;

  List<PaperRecord> get papers => List.unmodifiable(_papers);
  List<String> get extraCategories => List.unmodifiable(_extraCategories);
  List<String> get categories => [...baseCategories, ..._extraCategories];
  int get categoryIndex => _categoryIndex;
  int get currentPaperIndex => _currentPaperIndex;
  bool get gridMode => _gridMode;

  bool isLiked(String paperId) => _likedPaperIds.contains(paperId);
  bool isSaved(String paperId) => _savedPaperIds.contains(paperId);

  void toggleGridMode() {
    _gridMode = !_gridMode;
    notifyListeners();
  }

  void openPaper(int index) {
    if (index < 0 || index >= _papers.length) return;
    _currentPaperIndex = index;
    _gridMode = false;
    notifyListeners();
  }

  void selectPaper(int index) {
    if (index == _currentPaperIndex || index < 0 || index >= _papers.length) {
      return;
    }
    _currentPaperIndex = index;
    notifyListeners();
  }

  void selectCategory(int index) {
    if (index == _categoryIndex || index < 0 || index >= categories.length) {
      return;
    }
    _categoryIndex = index;
    notifyListeners();
  }

  void setExtraCategories(List<String> categories) {
    _extraCategories = List.of(categories);
    if (_categoryIndex >= this.categories.length) _categoryIndex = 0;
    notifyListeners();
  }

  void toggleLike(String paperId) {
    _toggleMembership(_likedPaperIds, paperId);
  }

  void toggleSave(String paperId) {
    _toggleMembership(_savedPaperIds, paperId);
  }

  void _toggleMembership(Set<String> values, String paperId) {
    if (values.contains(paperId)) {
      values.remove(paperId);
    } else {
      values.add(paperId);
    }
    notifyListeners();
  }
}
