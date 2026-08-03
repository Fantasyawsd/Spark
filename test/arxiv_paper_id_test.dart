import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/search/domain/arxiv_paper_id.dart';

void main() {
  group('extractArxivId', () {
    test('extracts modern arXiv IDs', () {
      expect(extractArxivId('2306.12345'), '2306.12345');
      expect(extractArxivId('2401.00001'), '2401.00001');
      expect(extractArxivId('1502.00001'), '1502.00001');
    });

    test('normalizes prefix, URL and version suffixes', () {
      expect(extractArxivId('arXiv:2306.12345'), '2306.12345');
      expect(
        extractArxivId('https://arxiv.org/abs/2306.12345v2'),
        '2306.12345',
      );
      expect(
        extractArxivId('http://arxiv.org/pdf/2401.00001.pdf'),
        '2401.00001',
      );
      expect(
        extractArxivId('https://export.arxiv.org/abs/hep-th/9901001v1'),
        'hep-th/9901001',
      );
    });

    test('extracts old-style category IDs', () {
      expect(extractArxivId('cs.CL/0112017'), 'cs.CL/0112017');
      expect(extractArxivId('hep-th/9901001'), 'hep-th/9901001');
    });

    test('returns null for keyword queries', () {
      expect(extractArxivId('LoRA'), isNull);
      expect(extractArxivId('attention is all you need'), isNull);
      expect(extractArxivId('2306.123'), isNull);
      expect(extractArxivId('机器学习'), isNull);
      expect(extractArxivId(''), isNull);
    });
  });
}
