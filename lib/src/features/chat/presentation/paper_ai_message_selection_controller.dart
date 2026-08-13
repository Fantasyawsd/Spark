import 'package:flutter/foundation.dart';

import '../domain/chat_message.dart';

class PaperAiMessageSelectionController extends ChangeNotifier {
  final Set<int> _selectedIndexes = <int>{};

  bool get active => _selectedIndexes.isNotEmpty;

  Set<int> get selectedIndexes => Set<int>.unmodifiable(_selectedIndexes);

  bool beginSelection(List<ChatMessage> messages, int index) {
    if (index < 0 || index >= messages.length) return false;

    _selectedIndexes
      ..clear()
      ..add(index);
    if (!messages[index].fromUser) {
      for (var previous = index - 1; previous >= 0; previous--) {
        if (messages[previous].fromUser) {
          _selectedIndexes.add(previous);
          break;
        }
      }
    }
    notifyListeners();
    return true;
  }

  void toggle(int index) {
    if (!active) return;
    if (!_selectedIndexes.remove(index)) {
      _selectedIndexes.add(index);
    }
    notifyListeners();
  }

  void clear() {
    if (_selectedIndexes.isEmpty) return;
    _selectedIndexes.clear();
    notifyListeners();
  }
}
