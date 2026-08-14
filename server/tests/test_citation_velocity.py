from __future__ import annotations

import unittest
from datetime import datetime, timezone

from spark_papers.citation_velocity import compute_citation_velocities
from spark_papers.models import PaperRecord
from spark_papers.sources import _normalize_openalex_record
from spark_papers.storage import PaperStore

UTC = timezone.utc


class ComputeCitationVelocitiesTest(unittest.TestCase):
    def setUp(self) -> None:
        self.as_of = datetime(2026, 7, 1, tzinfo=UTC)
        self.counts = [
            {'year': 2024, 'cited_by_count': 30},
            {'year': 2025, 'cited_by_count': 60},
            {'year': 2026, 'cited_by_count': 90},
        ]

    def test_trailing_three_year_average(self) -> None:
        total, _ = compute_citation_velocities(self.counts, self.as_of)
        self.assertEqual(total, 60.0)

    def test_short_window_interpolates_current_and_previous_year(self) -> None:
        _, short = compute_citation_velocities(self.counts, self.as_of)
        fraction = 181 / 365.25
        expected = 60 * (1 - fraction) + 90 * fraction
        self.assertAlmostEqual(short, expected, places=6)

    def test_single_year_leaves_both_velocities_missing(self) -> None:
        counts = [{'year': 2026, 'cited_by_count': 90}]
        total, short = compute_citation_velocities(counts, self.as_of)
        self.assertIsNone(total)
        self.assertIsNone(short)

    def test_empty_input_returns_none_pair(self) -> None:
        total, short = compute_citation_velocities([], self.as_of)
        self.assertIsNone(total)
        self.assertIsNone(short)

    def test_tuple_input_is_supported(self) -> None:
        counts = [(2024, 30), (2025, 60), (2026, 90)]
        total, _ = compute_citation_velocities(counts, self.as_of)
        self.assertEqual(total, 60.0)

    def test_invalid_entries_are_ignored(self) -> None:
        counts = [
            {'year': None, 'cited_by_count': 10},
            {'year': 2025, 'cited_by_count': None},
            {'year': 'bad', 'cited_by_count': 10},
            {'year': 2024, 'cited_by_count': -5},
            {'year': 2024, 'cited_by_count': 30},
        ]
        total, short = compute_citation_velocities(counts, self.as_of)
        self.assertIsNone(total)
        self.assertIsNone(short)


class NormalizeOpenalexRecordTest(unittest.TestCase):
    def test_counts_by_year_preserved(self) -> None:
        record = _normalize_openalex_record(
            {
                'id': 'https://openalex.org/W123',
                'cited_by_count': 90,
                'counts_by_year': [{'year': 2026, 'cited_by_count': 90}],
                'publication_year': 2026,
                'display_name': 'Paper',
            }
        )
        self.assertEqual(
            record['signals']['openalex']['counts_by_year'],
            [{'year': 2026, 'cited_by_count': 90}],
        )


class CitationVelocityIngestTest(unittest.TestCase):
    def test_ingest_derives_velocities_with_provenance(self) -> None:
        store = PaperStore(':memory:')
        try:
            now = datetime(2026, 7, 1, tzinfo=UTC)
            paper = PaperRecord(
                paper_id='paper-openalex-1',
                title='Paper With Citations',
                abstract='Abstract',
                authors=('Ada Lovelace',),
                published_at=datetime(2025, 1, 1, tzinfo=UTC),
                updated_at=None,
                subjects=('cs.AI',),
                external_ids={'arxiv_id': '2608.00002'},
                discovery_sources=('openalex',),
                signals={
                    'openalex': {
                        'citation_count': 90,
                        'counts_by_year': [
                            {'year': 2024, 'cited_by_count': 30},
                            {'year': 2025, 'cited_by_count': 60},
                            {'year': 2026, 'cited_by_count': 90},
                        ],
                    }
                },
                admitted=True,
            )
            store.ingest(
                paper,
                source='openalex',
                external_id='2608.00002',
                raw_payload={'cited_by_count': 90},
                fetched_at=now,
            )
            stored = store.get('paper-openalex-1')
            self.assertIsNotNone(stored)
            openalex = stored.signals['openalex']
            self.assertEqual(openalex['citation_velocity'], 60.0)
            fraction = 181 / 365.25
            self.assertAlmostEqual(
                openalex['short_citation_velocity'],
                60 * (1 - fraction) + 90 * fraction,
                places=6,
            )
            provenance = [
                item
                for item in stored.provenance
                if item.field_name == 'openalex_citation_velocity'
            ]
            self.assertEqual(len(provenance), 1)
            self.assertEqual(provenance[0].source, 'derived')
        finally:
            store.close()

    def test_ingest_without_counts_leaves_velocity_missing(self) -> None:
        store = PaperStore(':memory:')
        try:
            now = datetime(2026, 7, 1, tzinfo=UTC)
            paper = PaperRecord(
                paper_id='paper-openalex-2',
                title='Paper Without Counts',
                abstract='Abstract',
                authors=('Ada Lovelace',),
                published_at=datetime(2025, 1, 1, tzinfo=UTC),
                updated_at=None,
                subjects=('cs.AI',),
                external_ids={'arxiv_id': '2608.00003'},
                discovery_sources=('openalex',),
                signals={'openalex': {'citation_count': 42}},
                admitted=True,
            )
            store.ingest(
                paper,
                source='openalex',
                external_id='2608.00003',
                raw_payload={'cited_by_count': 42},
                fetched_at=now,
            )
            stored = store.get('paper-openalex-2')
            self.assertIsNotNone(stored)
            self.assertNotIn('citation_velocity', stored.signals['openalex'])
        finally:
            store.close()


if __name__ == '__main__':
    unittest.main()
