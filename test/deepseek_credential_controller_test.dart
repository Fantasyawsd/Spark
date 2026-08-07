import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/ai_settings/ai_settings.dart';
import 'package:spark/src/features/ai_settings/application/deepseek_credential_controller.dart';
import 'package:spark/src/features/ai_settings/data/in_memory_deepseek_credential_repository.dart';

void main() {
  test('loads, validates, replaces and deletes a stored credential', () async {
    final repository = InMemoryDeepSeekCredentialRepository('sk-old-1234');
    final validator = _RecordingValidator();
    final controller = DeepSeekCredentialController(
      repository: repository,
      validator: validator,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.configured, isTrue);
    expect(controller.maskedApiKey, 'sk-••••1234');

    expect(await controller.save(' sk-new-5678 '), isTrue);
    expect(validator.keys, ['sk-new-5678']);
    expect(await repository.readApiKey(), 'sk-new-5678');
    expect(controller.maskedApiKey, 'sk-••••5678');

    expect(await controller.delete(), isTrue);
    expect(controller.configured, isFalse);
    expect(await repository.readApiKey(), isNull);
  });

  test('does not replace the stored key when validation fails', () async {
    final repository = InMemoryDeepSeekCredentialRepository('sk-valid-1234');
    final controller = DeepSeekCredentialController(
      repository: repository,
      validator: _FailingValidator(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(await controller.save('sk-invalid'), isFalse);
    expect(await repository.readApiKey(), 'sk-valid-1234');
    expect(controller.error, 'API Key 无效。');
  });

  test('masks a one-character stored key without failing initialization',
      () async {
    final repository = InMemoryDeepSeekCredentialRepository('x');
    final controller = DeepSeekCredentialController(repository: repository);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.configured, isTrue);
    expect(controller.maskedApiKey, 'x••••');
    expect(controller.error, isNull);
  });
}

class _RecordingValidator implements DeepSeekCredentialValidator {
  final List<String> keys = [];

  @override
  Future<void> validate(String apiKey) async {
    keys.add(apiKey);
  }
}

class _FailingValidator implements DeepSeekCredentialValidator {
  @override
  Future<void> validate(String apiKey) async {
    throw const DeepSeekCredentialException('API Key 无效。');
  }
}
