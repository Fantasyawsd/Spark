import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/chat_session_settings.dart';

class ChatConversationSettingsState {
  ChatConversationSettingsState({
    required this.contextId,
    required ChatSessionSettingsRepository? repository,
    required bool Function() isDisposed,
    required VoidCallback notify,
  })  : _repository = repository,
        _isDisposed = isDisposed,
        _notify = notify;

  final String contextId;
  final ChatSessionSettingsRepository? _repository;
  final bool Function() _isDisposed;
  final VoidCallback _notify;

  ChatSessionSettings _value = ChatSessionSettings.empty;
  String? _persistenceError;
  int _revision = 0;

  ChatSessionSettings get value => _value;
  String? get persistenceError => _persistenceError;

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    final revision = _revision;
    try {
      final stored = await repository.load(contextId);
      if (!_isDisposed() && revision == _revision) {
        _value = stored;
      }
    } on ChatSessionSettingsPersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.chatConversationSettingsLoad,
        error,
        stackTrace,
      );
      if (!_isDisposed()) _persistenceError = error.message;
    }
  }

  Future<void> update(ChatSessionSettings settings) async {
    _revision++;
    _value = settings;
    _notify();
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.save(contextId, settings);
    } on ChatSessionSettingsPersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.chatConversationSettingsSave,
        error,
        stackTrace,
      );
      if (!_isDisposed()) _persistenceError = error.message;
    }
  }

  static void _reportPersistenceFailure(
    SparkDiagnosticOperation operation,
    Object error,
    StackTrace stackTrace,
  ) {
    SparkDiagnostics.reportUnexpected(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      severity: SparkDiagnosticSeverity.warning,
    );
  }
}
