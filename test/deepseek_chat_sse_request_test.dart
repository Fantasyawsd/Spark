import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/data/deepseek_chat_sse_request.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';

void main() {
  test('user cancellation remains expected control flow without diagnostics',
      () async {
    final cancellation = ChatRequestCancellation();
    final request = DeepSeekChatSseRequest(
      cancellation: cancellation,
      timeouts: const DeepSeekChatRequestTimeouts(
        header: Duration(seconds: 1),
        idle: Duration(seconds: 1),
        total: Duration(seconds: 2),
      ),
    );
    addTearDown(request.dispose);
    final source = StreamController<List<int>>();
    addTearDown(source.close);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      final expectation = expectLater(
        request.bindResponseStream(source.stream),
        emitsError(isA<ChatAiCancelledException>()),
      );
      cancellation.cancel();
      await expectation;
    });

    expect(events, isEmpty);
  });

  test('subscription cleanup failure is reported but cancellation survives',
      () async {
    final cancellation = ChatRequestCancellation();
    final request = DeepSeekChatSseRequest(
      cancellation: cancellation,
      timeouts: const DeepSeekChatRequestTimeouts(
        header: Duration(seconds: 1),
        idle: Duration(seconds: 1),
        total: Duration(seconds: 2),
      ),
    );
    addTearDown(request.dispose);
    late StreamController<List<int>> source;
    source = StreamController<List<int>>(
      onCancel: () async {
        throw StateError('private-cancellation-details');
      },
    );
    addTearDown(source.close);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      final expectation = expectLater(
        request.bindResponseStream(source.stream),
        emitsError(isA<ChatAiCancelledException>()),
      );
      cancellation.cancel();
      await expectation;
    });

    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.deepSeekCancelSubscription],
    );
    expect(events.single.severity, SparkDiagnosticSeverity.warning);
    expect(
        events.single.summary, isNot(contains('private-cancellation-details')));
  });
}
