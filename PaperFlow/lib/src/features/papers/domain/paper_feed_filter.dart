import 'paper.dart';

enum PaperFeedMode { recommended, following, latest }

class PaperFeedFilter {
  const PaperFeedFilter._();

  static List<PaperRecord> apply({
    required Iterable<PaperRecord> papers,
    required PaperFeedMode mode,
    required String topic,
    required Set<String> followedPaperIds,
  }) {
    final result = switch (mode) {
      PaperFeedMode.recommended => papers
          .where((paper) => PaperTopicMatcher.matches(paper, topic))
          .toList(),
      PaperFeedMode.following => papers
          .where((paper) =>
              followedPaperIds.contains(paper.authorKey) ||
              followedPaperIds.contains(paper.id))
          .toList(),
      PaperFeedMode.latest => papers.toList()
        ..sort((left, right) {
          final byDate = _publishedAt(right).compareTo(_publishedAt(left));
          return byDate != 0 ? byDate : left.id.compareTo(right.id);
        }),
    };
    return List.unmodifiable(result);
  }

  static DateTime _publishedAt(PaperRecord paper) =>
      paper.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class PaperTopicMatcher {
  const PaperTopicMatcher._();

  static const _aliases = <String, List<String>>{
    'LLM': ['llm', 'large language model', 'language models'],
    'NLP': ['cs.cl', 'nlp', 'natural language', 'language model', 'text'],
    'CV': ['cs.cv', 'computer vision', 'vision', 'image'],
    'Agent': ['agent', 'tool use', 'planning'],
    '多模态': ['multimodal', 'multi-modal', 'vision-language', 'cross-modal'],
    'Systems': [
      'cs.dc',
      'cs.os',
      'cs.pf',
      'distributed',
      'operating system',
      'computer systems',
    ],
    'Mathematics': ['math.', 'mathematics', 'theorem', 'proof'],
    'Biology': [
      'q-bio',
      'biology',
      'biomedical',
      'bioinformatics',
      'molecule',
      'chemical',
    ],
  };

  static bool matches(PaperRecord paper, String topic) {
    if (topic == '全部') return true;
    final normalizedTopic = topic.trim().toLowerCase();
    final searchable = [
      paper.title,
      paper.abstractText,
      paper.venue,
      ...paper.topics,
    ].join(' ').toLowerCase();
    final terms = _aliases[topic] ?? [normalizedTopic];
    return terms.any(searchable.contains);
  }
}
