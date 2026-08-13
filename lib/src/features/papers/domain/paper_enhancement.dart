import 'paper.dart';

class PaperEnhancement {
  const PaperEnhancement({
    this.citationCount,
    this.institutions = const [],
    this.concepts = const [],
    this.relatedWorkIds = const [],
  });

  final int? citationCount;
  final List<String> institutions;
  final List<String> concepts;
  final List<String> relatedWorkIds;
}

extension PaperEnhancementMerge on Paper {
  Paper applyEnhancement(PaperEnhancement enhancement) {
    return copyWith(
      affiliations: enhancement.institutions.isEmpty
          ? affiliations
          : enhancement.institutions,
      contentKeywords:
          enhancement.concepts.isEmpty ? contentKeywords : enhancement.concepts,
      citations: enhancement.citationCount ?? metrics.citations,
    );
  }
}
