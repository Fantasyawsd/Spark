import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spark/src/features/ai_settings/data/deepseek_api_credential_validator.dart';
import 'package:spark/src/features/ai_settings/domain/deepseek_credential_repository.dart';

void main() {
  test('validates a key through the DeepSeek balance endpoint', () async {
    late http.Request captured;
    final validator = DeepSeekApiCredentialValidator(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"is_available":true}', 200);
      }),
    );

    await validator.validate('sk-test');

    expect(captured.url.toString(), 'https://example.test/user/balance');
    expect(captured.headers['authorization'], 'Bearer sk-test');
  });

  test('reports an authentication failure without storing the key', () async {
    final validator = DeepSeekApiCredentialValidator(
      client: MockClient((_) async => http.Response('{}', 401)),
    );

    await expectLater(
      validator.validate('invalid'),
      throwsA(
        isA<DeepSeekCredentialException>().having(
          (error) => error.message,
          'message',
          contains('无效'),
        ),
      ),
    );
  });
}
