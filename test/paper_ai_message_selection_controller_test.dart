import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_message_selection_controller.dart';

void main() {
  const messages = [
    ChatMessage(fromUser: true, content: '问题一'),
    ChatMessage(fromUser: false, content: '回答一'),
    ChatMessage(fromUser: true, content: '问题二'),
    ChatMessage(fromUser: false, content: '回答二'),
  ];

  test('selecting an assistant also selects its nearest user prompt', () {
    final controller = PaperAiMessageSelectionController();
    addTearDown(controller.dispose);

    expect(controller.beginSelection(messages, 3), isTrue);

    expect(controller.active, isTrue);
    expect(controller.selectedIndexes, {2, 3});
  });

  test('selecting a user message only selects that message', () {
    final controller = PaperAiMessageSelectionController();
    addTearDown(controller.dispose);

    expect(controller.beginSelection(messages, 2), isTrue);

    expect(controller.selectedIndexes, {2});
  });

  test('invalid indexes do not enter selection mode', () {
    final controller = PaperAiMessageSelectionController();
    addTearDown(controller.dispose);

    expect(controller.beginSelection(messages, -1), isFalse);
    expect(controller.beginSelection(messages, messages.length), isFalse);
    expect(controller.active, isFalse);
    expect(controller.selectedIndexes, isEmpty);
  });

  test('toggling the final selection exits and clear resets all state', () {
    final controller = PaperAiMessageSelectionController();
    addTearDown(controller.dispose);

    controller.beginSelection(messages, 0);
    controller.toggle(0);

    expect(controller.active, isFalse);
    expect(controller.selectedIndexes, isEmpty);

    controller.beginSelection(messages, 3);
    controller.clear();
    expect(controller.active, isFalse);
    expect(controller.selectedIndexes, isEmpty);
  });
}
