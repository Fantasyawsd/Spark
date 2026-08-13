import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_content_fingerprint.dart';
import 'package:spark/src/features/papers/application/paper_keyword_service.dart';
import 'package:spark/src/features/papers/application/paper_translation_service.dart';
import 'package:spark/src/features/papers/domain/paper.dart';

void main() {
  test('translation and keyword fingerprints keep existing cache values', () {
    final paper = _paper(
      title: ' Paper title ',
      abstractText: ' Abstract text ',
    );

    expect(paperTranslationInputFingerprint(paper), '-65149991ac37f347');
    expect(paperKeywordInputFingerprint(paper), '6e79408cf30922c4');
  });

  test('fingerprint hashes UTF-8 input and isolates namespaces', () {
    final paper = _paper(title: '论文标题', abstractText: '包含中文的摘要。');

    expect(
      paperContentFingerprint(paper, namespace: '|spark-translation|'),
      '-4b17c9a23e8236af',
    );
    expect(
      paperContentFingerprint(paper, namespace: '|spark-keywords|'),
      '-47a6039ccc77a638',
    );
  });
}

Paper _paper({required String title, required String abstractText}) => Paper(
      id: 'paper-1',
      title: title,
      authors: const ['Author'],
      abstractText: abstractText,
      chineseAbstractMarkdown: '',
      readMinutes: 3,
    );
