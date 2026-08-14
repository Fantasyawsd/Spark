import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/data/providers/paper_api/paper_api_dto.dart';
import 'package:spark/src/features/papers/data/providers/paper_api/paper_api_mapper.dart';

void main() {
  const mapper = PaperApiMapper();

  PaperApiPaperDto dto({
    Map<String, Map<String, dynamic>> signals = const {},
  }) {
    return PaperApiPaperDto(
      paperId: 'paper_trend_test_000000000001',
      title: 'Trending Paper',
      abstractText: 'Abstract text.',
      authors: const ['Ada Lovelace'],
      publishedAt: DateTime.utc(2026, 7, 1),
      updatedAt: null,
      subjects: const ['cs.AI'],
      externalIds: const {'arxiv_id': '2608.00099'},
      discoverySources: const ['arxiv'],
      signals: signals,
      metadata: const {},
    );
  }

  test('提取 web_heat 的 trend_reason 与 trend_topics', () {
    final paper = mapper.toDomain(dto(signals: {
      'web_heat': {
        'trend_reason': 'Hacker News 讨论激增',
        'trend_topics': ['多模态', '推理'],
      },
    }));
    expect(paper.webTrendReason, 'Hacker News 讨论激增');
    expect(paper.webTrendTopics, ['多模态', '推理']);
  });

  test('无 web_heat 时字段保持空', () {
    final paper = mapper.toDomain(dto());
    expect(paper.webTrendReason, isNull);
    expect(paper.webTrendTopics, isEmpty);
  });

  test('非字符串与空值被过滤', () {
    final paper = mapper.toDomain(dto(signals: {
      'web_heat': {
        'trend_reason': 42,
        'trend_topics': ['多模态', '', 7, '   '],
      },
    }));
    expect(paper.webTrendReason, isNull);
    expect(paper.webTrendTopics, ['多模态']);
  });
}
