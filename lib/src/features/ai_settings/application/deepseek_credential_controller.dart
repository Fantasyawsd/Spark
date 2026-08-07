import 'package:flutter/foundation.dart';

import '../domain/deepseek_credential_repository.dart';

class DeepSeekCredentialController extends ChangeNotifier {
  DeepSeekCredentialController({
    required DeepSeekCredentialRepository repository,
    DeepSeekCredentialValidator? validator,
  })  : _repository = repository,
        _validator = validator;

  final DeepSeekCredentialRepository _repository;
  final DeepSeekCredentialValidator? _validator;

  bool _loading = true;
  bool _saving = false;
  bool _configured = false;
  String? _maskedApiKey;
  String? _error;
  bool _disposed = false;

  bool get loading => _loading;
  bool get saving => _saving;
  bool get configured => _configured;
  String? get maskedApiKey => _maskedApiKey;
  String? get error => _error;

  Future<void> initialize() async {
    _loading = true;
    _notifyIfMounted();
    try {
      final apiKey = await _repository.readApiKey();
      _setConfiguredKey(apiKey);
      _error = null;
    } on DeepSeekCredentialException catch (error) {
      _configured = false;
      _maskedApiKey = null;
      _error = error.message;
    } finally {
      _loading = false;
      _notifyIfMounted();
    }
  }

  Future<bool> save(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      _error = 'API Key 不能为空。';
      _notifyIfMounted();
      return false;
    }
    _saving = true;
    _error = null;
    _notifyIfMounted();
    try {
      await _validator?.validate(normalized);
      await _repository.saveApiKey(normalized);
      _setConfiguredKey(normalized);
      return true;
    } on DeepSeekCredentialException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _saving = false;
      _notifyIfMounted();
    }
  }

  Future<bool> delete() async {
    _saving = true;
    _error = null;
    _notifyIfMounted();
    try {
      await _repository.deleteApiKey();
      _setConfiguredKey(null);
      return true;
    } on DeepSeekCredentialException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _saving = false;
      _notifyIfMounted();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notifyIfMounted();
  }

  void _setConfiguredKey(String? apiKey) {
    final normalized = apiKey?.trim();
    _configured = normalized != null && normalized.isNotEmpty;
    _maskedApiKey = _configured ? _mask(normalized!) : null;
  }

  static String _mask(String value) {
    if (value.length <= 8) {
      final prefixLength = value.length < 2 ? value.length : 2;
      return '${value.substring(0, prefixLength)}••••';
    }
    return '${value.substring(0, 3)}••••${value.substring(value.length - 4)}';
  }

  void _notifyIfMounted() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
