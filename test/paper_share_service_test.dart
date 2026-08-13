import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/platform/spark_clipboard.dart';
import 'package:spark/src/features/papers/application/paper_share_service.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'support/demo_paper_repository.dart';
import 'package:spark/src/features/papers/data/platform_paper_share_service.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_share.dart';

void main() {
  test('share payload contains paper metadata, abstract and URL', () {
    final paper = const DemoPaperRepository().getAll().first;
    final payload = PaperShareComposer.compose(paper);

    expect(payload.subject, paper.title);
    expect(payload.text, contains(paper.title));
    expect(payload.text, contains('Edward J. Hu'));
    expect(payload.text, contains(paper.venue));
    expect(payload.text, contains('Low-Rank Adaptation'));
    expect(payload.text, contains('Spark 本地论文，暂无公开链接'));
  });

  test('share payload prefers the public paper URL', () {
    final paper = const ArxivSeedRepository().getAll().first;
    final payload = PaperShareComposer.compose(paper);

    expect(payload.text, contains('https://arxiv.org/abs/2402.06734'));
  });

  test('share payload removes Markdown markers without deleting content', () {
    final source = const ArxivSeedRepository().getAll().first;
    final paper = Paper(
      id: source.id,
      title: source.title,
      authors: source.authors,
      publishedAt: source.publishedAt,
      abstractText: '''# Heading 0

> Read [paper 2020](https://example.com) with **bold**, *italic*,
~~removed~~ and `inline code 0`.''',
      chineseAbstractMarkdown: '',
      relatedPapers: source.relatedPapers,
      readMinutes: source.readMinutes,
      citations: source.metrics.citations,
      likes: source.metrics.likes,
      comments: source.metrics.comments,
      saves: source.metrics.saves,
      shares: source.metrics.shares,
    );

    final payload = PaperShareComposer.compose(paper);

    expect(
      payload.text,
      contains(
        'Heading 0 Read paper 2020 with bold, italic, removed and '
        'inline code 0.',
      ),
    );
    expect(payload.text, isNot(contains('https://example.com')));
    expect(payload.text, isNot(contains('`')));
    expect(payload.text, isNot(contains('**')));
    expect(payload.text, isNot(contains('~~')));
  });

  test('desktop sharing copies through the injected clipboard adapter',
      () async {
    final clipboard = _RecordingClipboard();
    final service = PlatformPaperShareService(clipboard: clipboard);
    const payload = PaperSharePayload(subject: 'Paper', text: 'Share text');

    final result = await service.share(payload);

    expect(result, PaperShareResult.copied);
    expect(clipboard.copiedText, 'Share text');
  });

  test('clipboard failures are normalized as paper share failures', () async {
    final service = PlatformPaperShareService(
      clipboard: _ThrowingClipboard(),
    );

    await expectLater(
      service.share(
        const PaperSharePayload(subject: 'Paper', text: 'Share text'),
      ),
      throwsA(
        isA<PaperShareException>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
  });
}

class _RecordingClipboard implements SparkClipboard {
  String? copiedText;

  @override
  Future<void> copyText(String text) async => copiedText = text;
}

class _ThrowingClipboard implements SparkClipboard {
  @override
  Future<void> copyText(String text) {
    throw StateError('simulated clipboard failure');
  }
}
