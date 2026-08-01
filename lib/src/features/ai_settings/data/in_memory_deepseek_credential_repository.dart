import '../domain/deepseek_credential_repository.dart';

class InMemoryDeepSeekCredentialRepository
    implements DeepSeekCredentialRepository {
  InMemoryDeepSeekCredentialRepository([String? apiKey]) : _apiKey = apiKey;

  String? _apiKey;

  @override
  Future<String?> readApiKey() async => _apiKey;

  @override
  Future<void> saveApiKey(String apiKey) async {
    _apiKey = apiKey.trim();
  }

  @override
  Future<void> deleteApiKey() async {
    _apiKey = null;
  }
}
