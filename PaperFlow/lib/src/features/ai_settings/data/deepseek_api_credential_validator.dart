import 'dart:async';

import 'package:http/http.dart' as http;

import '../domain/deepseek_credential_repository.dart';

class DeepSeekApiCredentialValidator implements DeepSeekCredentialValidator {
  DeepSeekApiCredentialValidator({
    this.baseUrl = const String.fromEnvironment(
      'DEEPSEEK_BASE_URL',
      defaultValue: 'https://api.deepseek.com',
    ),
    this.timeout = const Duration(seconds: 15),
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<void> validate(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      throw const DeepSeekCredentialException('API Key 不能为空。');
    }
    final endpoint = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    try {
      final response = await _client.get(
        Uri.parse('$endpoint/user/balance'),
        headers: {'Authorization': 'Bearer $normalized'},
      ).timeout(timeout);
      if (response.statusCode == 200) return;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const DeepSeekCredentialException('API Key 无效，请检查后重试。');
      }
      if (response.statusCode == 429) {
        throw const DeepSeekCredentialException('DeepSeek 请求过于频繁，请稍后重试。');
      }
      throw DeepSeekCredentialException(
        '无法验证 API Key（HTTP ${response.statusCode}）。',
      );
    } on DeepSeekCredentialException {
      rethrow;
    } on TimeoutException catch (error) {
      throw DeepSeekCredentialException('验证 API Key 超时，请检查网络。', error);
    } on Object catch (error) {
      throw DeepSeekCredentialException('无法连接 DeepSeek 验证 API Key。', error);
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
