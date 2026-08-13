import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/chat_ai_service.dart';

class DeepSeekChatRequestTimeouts {
  const DeepSeekChatRequestTimeouts({
    this.header = const Duration(seconds: 60),
    this.idle = const Duration(seconds: 45),
    this.total = const Duration(minutes: 5),
  });

  final Duration header;
  final Duration idle;
  final Duration total;
}

enum _DeepSeekAbortReason {
  cancelled,
  headerTimeout,
  idleTimeout,
  totalTimeout
}

/// 为一次 HTTP/SSE 请求提供取消和超时边界，不持有或关闭 HTTP client。
class DeepSeekChatSseRequest {
  DeepSeekChatSseRequest({
    required ChatRequestCancellation cancellation,
    required this.timeouts,
  }) : _cancellation = cancellation {
    _totalTimer = Timer(
      timeouts.total,
      () => _abort(_DeepSeekAbortReason.totalTimeout),
    );
    unawaited(
      _cancellation.whenCancelled.then(
        (_) => _abort(_DeepSeekAbortReason.cancelled),
      ),
    );
  }

  final ChatRequestCancellation _cancellation;
  final DeepSeekChatRequestTimeouts timeouts;
  final Completer<_DeepSeekAbortReason> _abortReason =
      Completer<_DeepSeekAbortReason>();
  late final Timer _totalTimer;
  _DeepSeekAbortReason? _reason;
  bool _disposed = false;

  late final Future<void> abortTrigger = _abortReason.future.then((_) {});

  Object? get abortError => _reason == null ? null : _errorFor(_reason!);

  Future<T> waitForHeaders<T>(Future<T> response) async {
    final headerTimer = Timer(
      timeouts.header,
      () => _abort(_DeepSeekAbortReason.headerTimeout),
    );
    try {
      return await Future.any<T>([
        response,
        _abortReason.future.then<T>((reason) => throw _errorFor(reason)),
      ]);
    } finally {
      headerTimer.cancel();
    }
  }

  Stream<List<int>> bindResponseStream(Stream<List<int>> source) {
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    Timer? idleTimer;
    var finished = false;

    void resetIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(
        timeouts.idle,
        () => _abort(_DeepSeekAbortReason.idleTimeout),
      );
    }

    void closeWithError(Object error, [StackTrace? stackTrace]) {
      if (finished) return;
      finished = true;
      idleTimer?.cancel();
      controller.addError(error, stackTrace);
      unawaited(controller.close());
    }

    controller = StreamController<List<int>>(
      onListen: () {
        resetIdleTimer();
        subscription = source.listen(
          (data) {
            if (finished) return;
            resetIdleTimer();
            controller.add(data);
          },
          onError: (Object error, StackTrace stackTrace) {
            final normalized =
                error is http.RequestAbortedException && _reason != null
                    ? _errorFor(_reason!)
                    : error;
            closeWithError(normalized, stackTrace);
          },
          onDone: () {
            if (finished) return;
            finished = true;
            idleTimer?.cancel();
            unawaited(controller.close());
          },
        );
        unawaited(
          _abortReason.future.then((reason) async {
            if (finished) return;
            try {
              await subscription?.cancel();
            } on Object catch (error, stackTrace) {
              SparkDiagnostics.reportUnexpected(
                operation: SparkDiagnosticOperation.deepSeekCancelSubscription,
                error: error,
                stackTrace: stackTrace,
                severity: SparkDiagnosticSeverity.warning,
              );
              // The canonical cancellation or timeout must still reach callers.
            }
            closeWithError(_errorFor(reason));
          }),
        );
      },
      onCancel: () async {
        if (finished) return;
        finished = true;
        idleTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  void dispose() {
    _disposed = true;
    _totalTimer.cancel();
  }

  void _abort(_DeepSeekAbortReason reason) {
    if (_disposed || _abortReason.isCompleted) return;
    _reason = reason;
    _abortReason.complete(reason);
  }

  static Object _errorFor(_DeepSeekAbortReason reason) {
    return switch (reason) {
      _DeepSeekAbortReason.cancelled => const ChatAiCancelledException(),
      _DeepSeekAbortReason.headerTimeout =>
        TimeoutException('DeepSeek response headers timed out.'),
      _DeepSeekAbortReason.idleTimeout =>
        TimeoutException('DeepSeek response stream became idle.'),
      _DeepSeekAbortReason.totalTimeout =>
        TimeoutException('DeepSeek request exceeded its total timeout.'),
    };
  }
}
