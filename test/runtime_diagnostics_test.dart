import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';

void main() {
  test(
    'diagnostic events expose fixed metadata without stringifying errors',
    () {
      final events = <SparkDiagnosticEvent>[];
      final error = _SensitiveError('deepseek-secret-prompt');
      final stackTrace = StackTrace.current;

      SparkDiagnostics.runWithSink(events.add, () {
        SparkDiagnostics.reportUnexpected(
          operation: SparkDiagnosticOperation.flutterFramework,
          error: error,
          stackTrace: stackTrace,
        );
      });

      expect(error.toStringCalls, 0);
      expect(events, hasLength(1));
      expect(
        events.single.operation,
        SparkDiagnosticOperation.flutterFramework,
      );
      expect(events.single.severity, SparkDiagnosticSeverity.error);
      expect(events.single.errorType, '_SensitiveError');
      expect(events.single.stackTrace, same(stackTrace));
      expect(events.single.summary, 'unexpected_error type=_SensitiveError');
      expect(events.single.summary, isNot(contains('deepseek-secret-prompt')));
    },
  );

  test('guarded zone reports and preserves the original synchronous error', () {
    final events = <SparkDiagnosticEvent>[];
    final error = StateError('sensitive-request-body');

    expect(
      () => SparkDiagnostics.runWithSink(
        events.add,
        () => SparkDiagnostics.runGuarded<void>(() => throw error),
      ),
      throwsA(same(error)),
    );

    expect(events, hasLength(1));
    expect(
      events.single.operation,
      SparkDiagnosticOperation.dartUnhandled,
    );
    expect(events.single.errorType, 'StateError');
    expect(events.single.summary, isNot(contains('sensitive-request-body')));
  });

  test('guarded zone reports and forwards async errors to its parent',
      () async {
    final events = <SparkDiagnosticEvent>[];
    final error = StateError('private-chat-content');
    final propagated = Completer<Object>();

    await runZonedGuarded(
      () async {
        SparkDiagnostics.runWithSink(events.add, () {
          SparkDiagnostics.runGuarded<void>(() {
            scheduleMicrotask(() => throw error);
          });
        });
        await Future<void>.delayed(Duration.zero);
      },
      (forwardedError, stackTrace) {
        if (!propagated.isCompleted) propagated.complete(forwardedError);
      },
    );

    expect(await propagated.future, same(error));
    expect(events, hasLength(1));
    expect(events.single.operation, SparkDiagnosticOperation.dartUnhandled);
    expect(events.single.errorType, 'StateError');
    expect(events.single.summary, isNot(contains('private-chat-content')));
  });

  test('flutter binding reports framework errors and calls prior handler', () {
    final events = <SparkDiagnosticEvent>[];
    final originalFrameworkHandler = FlutterError.onError;
    final originalPlatformHandler = PlatformDispatcher.instance.onError;
    FlutterErrorDetails? forwardedDetails;
    FlutterError.onError = (details) => forwardedDetails = details;
    PlatformDispatcher.instance.onError = null;
    addTearDown(() {
      FlutterError.onError = originalFrameworkHandler;
      PlatformDispatcher.instance.onError = originalPlatformHandler;
    });

    late FlutterRuntimeDiagnosticsBinding binding;
    SparkDiagnostics.runWithSink(events.add, () {
      binding = FlutterRuntimeDiagnosticsBinding.install();
      final details = FlutterErrorDetails(
        exception: _SensitiveError('private-paper-content'),
        stack: StackTrace.current,
      );
      FlutterError.onError!(details);
      expect(forwardedDetails, same(details));
    });
    binding.restore();

    expect(events, hasLength(1));
    expect(events.single.operation, SparkDiagnosticOperation.flutterFramework);
    expect(events.single.summary, isNot(contains('private-paper-content')));
    expect(FlutterError.onError, isNotNull);
  });

  test('flutter binding preserves the previous platform handled result', () {
    final events = <SparkDiagnosticEvent>[];
    final originalFrameworkHandler = FlutterError.onError;
    final originalPlatformHandler = PlatformDispatcher.instance.onError;
    var forwarded = false;
    FlutterError.onError = (_) {};
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      forwarded = true;
      return true;
    };
    addTearDown(() {
      FlutterError.onError = originalFrameworkHandler;
      PlatformDispatcher.instance.onError = originalPlatformHandler;
    });

    late FlutterRuntimeDiagnosticsBinding binding;
    late bool handled;
    SparkDiagnostics.runWithSink(events.add, () {
      binding = FlutterRuntimeDiagnosticsBinding.install();
      handled = PlatformDispatcher.instance.onError!(
        _SensitiveError('authorization-header'),
        StackTrace.current,
      );
    });
    binding.restore();

    expect(handled, isTrue);
    expect(forwarded, isTrue);
    expect(events, hasLength(1));
    expect(events.single.operation, SparkDiagnosticOperation.flutterPlatform);
    expect(events.single.summary, isNot(contains('authorization-header')));
  });

  test(
    'flutter binding keeps platform errors unhandled without a prior hook',
    () {
      final events = <SparkDiagnosticEvent>[];
      final originalFrameworkHandler = FlutterError.onError;
      final originalPlatformHandler = PlatformDispatcher.instance.onError;
      FlutterError.onError = (_) {};
      PlatformDispatcher.instance.onError = null;
      addTearDown(() {
        FlutterError.onError = originalFrameworkHandler;
        PlatformDispatcher.instance.onError = originalPlatformHandler;
      });

      late FlutterRuntimeDiagnosticsBinding binding;
      late bool handled;
      SparkDiagnostics.runWithSink(events.add, () {
        binding = FlutterRuntimeDiagnosticsBinding.install();
        handled = PlatformDispatcher.instance.onError!(
          StateError('database-path'),
          StackTrace.current,
        );
      });
      binding.restore();

      expect(handled, isFalse);
      expect(events, hasLength(1));
      expect(events.single.errorType, 'StateError');
    },
  );
}

final class _SensitiveError implements Exception {
  _SensitiveError(this.secret);

  final String secret;
  int toStringCalls = 0;

  @override
  String toString() {
    toStringCalls++;
    return secret;
  }
}
