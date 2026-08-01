import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  test('share payload contains paper metadata, abstract and URL', () {
    final paper = const DemoPaperRepository().getAll().first;
    final payload = PaperShareComposer.compose(paper);

    expect(payload.subject, paper.title);
    expect(payload.text, contains(paper.title));
    expect(payload.text, contains('Edward J. Hu'));
    expect(payload.text, contains(paper.venue));
    expect(payload.text, contains('Low-Rank Adaptation'));
    expect(payload.text, contains('PaperFlow 本地论文，暂无公开链接'));
  });

  test('share payload prefers the public paper URL', () {
    final paper = const ArxivSeedRepository().getAll().first;
    final payload = PaperShareComposer.compose(paper);

    expect(payload.text, contains('https://arxiv.org/abs/2402.06734'));
  });
}
