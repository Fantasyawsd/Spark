import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/application/chat_conversation_write_queue.dart';

void main() {
  test('serializes writes and flushes the latest queued operation', () async {
    final events = <String>[];
    final queue = ChatConversationWriteQueue(
      onQueueError: (error, stackTrace) {},
    );

    final first = queue.enqueue(() async {
      events.add('first-start');
      await Future<void>.delayed(Duration.zero);
      events.add('first-end');
    });
    final second = queue.enqueue(() async {
      events.add('second');
    });

    await queue.flush();
    await Future.wait([first, second]);

    expect(events, ['first-start', 'first-end', 'second']);
  });

  test('reports queue failures and keeps later writes running', () async {
    final errors = <Object>[];
    final events = <String>[];
    final queue = ChatConversationWriteQueue(
      onQueueError: (error, stackTrace) => errors.add(error),
    );

    final failed = queue.enqueue(() async {
      throw StateError('failed write');
    });
    final succeeding = queue.enqueue(() async {
      events.add('succeeded');
    });

    await expectLater(failed, throwsStateError);
    await succeeding;
    await queue.flush();

    expect(events, ['succeeded']);
    expect(errors, hasLength(1));
  });
}
