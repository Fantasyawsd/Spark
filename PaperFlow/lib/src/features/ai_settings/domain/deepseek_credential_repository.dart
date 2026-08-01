abstract interface class DeepSeekCredentialRepository {
  Future<String?> readApiKey();

  Future<void> saveApiKey(String apiKey);

  Future<void> deleteApiKey();
}

abstract interface class DeepSeekCredentialValidator {
  Future<void> validate(String apiKey);
}

class DeepSeekCredentialException implements Exception {
  const DeepSeekCredentialException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
