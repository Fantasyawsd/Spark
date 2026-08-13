import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_enhancement.dart';

void main() {
  test('enhancement updates only its three owned fields', () {
    final original = _completePaper();

    final enhanced = original.applyEnhancement(
      const PaperEnhancement(
        citationCount: 42,
        institutions: ['Enhanced Institute'],
        concepts: ['Enhanced Concept'],
        relatedWorkIds: ['W123'],
      ),
    );

    expect(enhanced.affiliations, ['Enhanced Institute']);
    expect(enhanced.contentKeywords, ['Enhanced Concept']);
    expect(enhanced.metrics.citations, 42);
    _expectNonEnhancementFieldsUnchanged(original, enhanced);
    expect(
      () => enhanced.affiliations.add('Mutable Institute'),
      throwsUnsupportedError,
    );
    expect(
      () => enhanced.contentKeywords.add('Mutable Concept'),
      throwsUnsupportedError,
    );
  });

  test('empty enhancement preserves existing values and unknown citations', () {
    final withKnownCitation = _completePaper();
    final withUnknownCitation = _completePaper().copyWith(
      clearCitations: true,
    );

    final preserved = withKnownCitation.applyEnhancement(
      const PaperEnhancement(),
    );
    final unknownPreserved = withUnknownCitation.applyEnhancement(
      const PaperEnhancement(),
    );

    expect(preserved.affiliations, withKnownCitation.affiliations);
    expect(preserved.contentKeywords, withKnownCitation.contentKeywords);
    expect(preserved.metrics.citations, 7);
    expect(unknownPreserved.metrics.citations, isNull);
  });

  test('copyWith can explicitly clear nullable fields', () {
    final copied = _completePaper().copyWith(
      clearPrimarySubject: true,
      clearVenue: true,
      clearJournalReference: true,
      clearComment: true,
      clearCitations: true,
      clearArxivId: true,
      clearDoi: true,
      clearPaperUrl: true,
      clearPdfUrl: true,
      clearPublishedAt: true,
      clearUpdatedAt: true,
      clearLicense: true,
    );

    expect(copied.primarySubject, isNull);
    expect(copied.venue, isNull);
    expect(copied.journalReference, isNull);
    expect(copied.comment, isNull);
    expect(copied.metrics.citations, isNull);
    expect(copied.arxivId, isNull);
    expect(copied.doi, isNull);
    expect(copied.paperUrl, isNull);
    expect(copied.pdfUrl, isNull);
    expect(copied.publishedAt, isNull);
    expect(copied.updatedAt, isNull);
    expect(copied.license, isNull);
  });
}

Paper _completePaper() => Paper(
      id: 'paper-1',
      title: 'Complete paper',
      authors: const ['Ada Lovelace', 'Grace Hopper'],
      affiliations: const ['Original Institute'],
      contentKeywords: const ['Original Concept'],
      subjects: const ['cs.AI', 'cs.LG'],
      primarySubject: 'cs.AI',
      venue: 'ICML 2026',
      journalReference: 'Journal 1 (2026)',
      comment: 'Oral presentation',
      abstractText: 'Original Abstract',
      chineseAbstractMarkdown: '原始摘要',
      relatedPapers: const [
        RelatedPaper(
          id: 'related-1',
          title: 'Related paper',
          venue: 'NeurIPS 2025',
          relation: 'Shared method',
        ),
      ],
      readMinutes: 9,
      citations: 7,
      likes: 3,
      comments: 4,
      saves: 5,
      shares: 6,
      arxivId: '2601.00001',
      doi: '10.1000/paper',
      paperUrl: 'https://arxiv.org/abs/2601.00001',
      pdfUrl: 'https://arxiv.org/pdf/2601.00001',
      publishedAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      license: 'CC BY 4.0',
      source: 'arxiv',
    );

void _expectNonEnhancementFieldsUnchanged(Paper before, Paper after) {
  expect(after.id, before.id);
  expect(after.title, before.title);
  expect(after.authors, before.authors);
  expect(after.subjects, before.subjects);
  expect(after.primarySubject, before.primarySubject);
  expect(after.venue, before.venue);
  expect(after.journalReference, before.journalReference);
  expect(after.comment, before.comment);
  expect(
    after.content.originalAbstractMarkdown,
    before.content.originalAbstractMarkdown,
  );
  expect(
    after.content.chineseAbstractMarkdown,
    before.content.chineseAbstractMarkdown,
  );
  expect(after.relatedPapers, before.relatedPapers);
  expect(after.readMinutes, before.readMinutes);
  expect(after.metrics.likes, before.metrics.likes);
  expect(after.metrics.comments, before.metrics.comments);
  expect(after.metrics.saves, before.metrics.saves);
  expect(after.metrics.shares, before.metrics.shares);
  expect(after.arxivId, before.arxivId);
  expect(after.doi, before.doi);
  expect(after.paperUrl, before.paperUrl);
  expect(after.pdfUrl, before.pdfUrl);
  expect(after.publishedAt, before.publishedAt);
  expect(after.updatedAt, before.updatedAt);
  expect(after.license, before.license);
  expect(after.source, before.source);
}
