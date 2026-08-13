import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spark/src/features/ai_settings/data/secure_deepseek_credential_repository.dart';
import 'package:spark/src/features/ai_settings/domain/deepseek_credential_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  final calls = <MethodCall>[];
  String? failingMethod;

  setUp(() {
    values.clear();
    calls.clear();
    failingMethod = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == failingMethod) {
        throw PlatformException(code: 'secure-storage-failure');
      }
      switch (call.method) {
        case 'write':
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          values[args['key']! as String] = args['value']! as String;
          return null;
        case 'read':
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          return values[args['key'] as String];
        case 'delete':
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          values.remove(args['key'] as String);
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('saves and reads a trimmed key, then deletes it', () async {
    final repository = SecureDeepSeekCredentialRepository(
      storage: const FlutterSecureStorage(),
    );

    await repository.saveApiKey('  secret-key  ');
    expect(await repository.readApiKey(), 'secret-key');
    await repository.deleteApiKey();
    expect(await repository.readApiKey(), isNull);
    expect(calls.map((call) => call.method), [
      'write',
      'read',
      'delete',
      'read',
    ]);
    expect(values, isEmpty);
  });

  test('rejects an empty key without touching secure storage', () async {
    final repository = SecureDeepSeekCredentialRepository(
      storage: const FlutterSecureStorage(),
    );

    await expectLater(
      repository.saveApiKey(' \n\t '),
      throwsA(isA<DeepSeekCredentialException>()),
    );
    expect(calls, isEmpty);
  });

  for (final operation in ['write', 'read', 'delete']) {
    test('$operation failures use the credential exception boundary', () async {
      final repository = SecureDeepSeekCredentialRepository(
        storage: const FlutterSecureStorage(),
      );
      failingMethod = operation;

      final Future<void> request = switch (operation) {
        'write' => repository.saveApiKey('private-api-key'),
        'read' => repository.readApiKey().then<void>((_) {}),
        _ => repository.deleteApiKey(),
      };

      await expectLater(
        request,
        throwsA(
          isA<DeepSeekCredentialException>()
              .having((error) => error.cause, 'cause', isA<PlatformException>())
              .having(
                (error) => error.toString(),
                'message',
                isNot(contains('private-api-key')),
              ),
        ),
      );
    });
  }
}
