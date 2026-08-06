import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/deepseek_credential_repository.dart';

class SecureDeepSeekCredentialRepository
    implements DeepSeekCredentialRepository {
  SecureDeepSeekCredentialRepository({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                storageNamespace: 'spark.ai',
                resetOnError: false,
              ),
            );

  static const _apiKeyStorageKey = 'deepseek_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readApiKey() async {
    try {
      final value = await _storage.read(key: _apiKeyStorageKey);
      final normalized = value?.trim();
      return normalized == null || normalized.isEmpty ? null : normalized;
    } on PlatformException catch (error) {
      throw DeepSeekCredentialException('无法读取安全存储中的 API Key。', error);
    }
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      throw const DeepSeekCredentialException('API Key 不能为空。');
    }
    try {
      await _storage.write(key: _apiKeyStorageKey, value: normalized);
    } on PlatformException catch (error) {
      throw DeepSeekCredentialException('无法将 API Key 保存到安全存储。', error);
    }
  }

  @override
  Future<void> deleteApiKey() async {
    try {
      await _storage.delete(key: _apiKeyStorageKey);
    } on PlatformException catch (error) {
      throw DeepSeekCredentialException('无法从安全存储删除 API Key。', error);
    }
  }
}
