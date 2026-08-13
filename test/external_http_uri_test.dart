import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/platform/external_http_uri.dart';

void main() {
  group('validExternalHttpUri', () {
    test('accepts trimmed HTTP and HTTPS addresses', () {
      expect(
        validExternalHttpUri(' https://example.test/paper '),
        Uri.parse('https://example.test/paper'),
      );
      expect(
        validExternalHttpUri('http://example.test'),
        Uri.parse('http://example.test'),
      );
    });

    test('rejects missing, relative, hostless, and non-web addresses', () {
      for (final value in <String?>[
        null,
        '',
        '   ',
        '/relative/path',
        'https:///missing-host',
        'file:///tmp/paper.pdf',
        'mailto:author@example.test',
        'javascript:alert(1)',
      ]) {
        expect(validExternalHttpUri(value), isNull, reason: '$value');
      }
    });
  });
}
