import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'runtime_diagnostics.dart';

/// 将 Flutter framework 与平台根 isolate 错误接入统一诊断通道。
final class FlutterRuntimeDiagnosticsBinding {
  FlutterRuntimeDiagnosticsBinding._({
    required FlutterExceptionHandler frameworkHandler,
    required ErrorCallback platformHandler,
    required FlutterExceptionHandler? previousFrameworkHandler,
    required ErrorCallback? previousPlatformHandler,
  })  : _frameworkHandler = frameworkHandler,
        _platformHandler = platformHandler,
        _previousFrameworkHandler = previousFrameworkHandler,
        _previousPlatformHandler = previousPlatformHandler;

  final FlutterExceptionHandler _frameworkHandler;
  final ErrorCallback _platformHandler;
  final FlutterExceptionHandler? _previousFrameworkHandler;
  final ErrorCallback? _previousPlatformHandler;
  bool _restored = false;

  static FlutterRuntimeDiagnosticsBinding install() {
    final previousFrameworkHandler = FlutterError.onError;
    final previousPlatformHandler = PlatformDispatcher.instance.onError;

    late final FlutterExceptionHandler frameworkHandler;
    frameworkHandler = (details) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.flutterFramework,
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
      );
      previousFrameworkHandler?.call(details);
    };

    late final ErrorCallback platformHandler;
    platformHandler = (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.flutterPlatform,
        error: error,
        stackTrace: stackTrace,
      );
      return previousPlatformHandler?.call(error, stackTrace) ?? false;
    };

    FlutterError.onError = frameworkHandler;
    PlatformDispatcher.instance.onError = platformHandler;
    return FlutterRuntimeDiagnosticsBinding._(
      frameworkHandler: frameworkHandler,
      platformHandler: platformHandler,
      previousFrameworkHandler: previousFrameworkHandler,
      previousPlatformHandler: previousPlatformHandler,
    );
  }

  /// 仅恢复仍由本实例持有的 handler，避免覆盖安装后的其他合法接线。
  void restore() {
    if (_restored) return;
    _restored = true;
    if (identical(FlutterError.onError, _frameworkHandler)) {
      FlutterError.onError = _previousFrameworkHandler;
    }
    if (identical(PlatformDispatcher.instance.onError, _platformHandler)) {
      PlatformDispatcher.instance.onError = _previousPlatformHandler;
    }
  }
}
