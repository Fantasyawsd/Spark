from __future__ import annotations

import unittest
from datetime import datetime, timezone

from spark_papers.api import PaperApiService
from spark_papers.models import PaperRecord
from spark_papers.storage import PaperStore

UTC = timezone.utc


def _seed_paper(store: PaperStore, paper_id: str = 'paper-web-1') -> None:
    paper = PaperRecord(
        paper_id=paper_id,
        title='Trending Paper',
        abstract='Abstract',
        authors=('Ada Lovelace',),
        published_at=datetime(2026, 7, 1, tzinfo=UTC),
        updated_at=None,
        subjects=('cs.AI',),
        external_ids={'arxiv_id': '2608.00010'},
        discovery_sources=('arxiv',),
        admitted=True,
    )
    store.ingest(
        paper,
        source='arxiv',
        external_id='2608.00010',
        raw_payload={'title': paper.title},
        fetched_at=datetime(2026, 8, 1, tzinfo=UTC),
    )


class RecordWebHeatTest(unittest.TestCase):
    def setUp(self) -> None:
        self.store = PaperStore(':memory:')
        _seed_paper(self.store)
        self.now = datetime(2026, 8, 14, tzinfo=UTC)
        self.payload = {
            'web_heat_score': 0.87,
            'web_mentions': 42,
            'web_source_count': 7,
            'trend_detected_at': self.now.isoformat(),
            'trend_reason': 'Hacker News 讨论激增',
            'trend_topics': ['多模态', '推理'],
        }

    def tearDown(self) -> None:
        self.store.close()

    def test_record_writes_signals_and_provenance(self) -> None:
        written = self.store.record_web_heat('paper-web-1', self.payload, as_of=self.now)
        self.assertTrue(written)
        paper = self.store.get('paper-web-1')
        self.assertIsNotNone(paper)
        web_heat = paper.signals['web_heat']
        self.assertEqual(web_heat['web_heat_score'], 0.87)
        self.assertEqual(web_heat['web_mentions'], 42)
        self.assertEqual(web_heat['trend_reason'], 'Hacker News 讨论激增')
        self.assertEqual(web_heat['trend_topics'], ['多模态', '推理'])
        provenance = [
            item for item in paper.provenance if item.field_name == 'web_heat'
        ]
        self.assertEqual(len(provenance), 1)
        self.assertEqual(provenance[0].source, 'web_heat')

    def test_record_overwrites_previous_payload(self) -> None:
        self.store.record_web_heat('paper-web-1', self.payload, as_of=self.now)
        self.store.record_web_heat(
            'paper-web-1',
            {'web_heat_score': 0.1, 'web_mentions': 1},
            as_of=self.now,
        )
        paper = self.store.get('paper-web-1')
        web_heat = paper.signals['web_heat']
        self.assertEqual(web_heat['web_heat_score'], 0.1)
        self.assertNotIn('trend_reason', web_heat)

    def test_unknown_paper_returns_false_and_creates_nothing(self) -> None:
        written = self.store.record_web_heat('paper-missing', self.payload, as_of=self.now)
        self.assertFalse(written)
        self.assertIsNone(self.store.get('paper-missing'))

    def test_none_fields_are_dropped(self) -> None:
        payload = {'web_heat_score': None, 'web_mentions': 3, 'trend_reason': None}
        self.store.record_web_heat('paper-web-1', payload, as_of=self.now)
        web_heat = self.store.get('paper-web-1').signals['web_heat']
        self.assertNotIn('web_heat_score', web_heat)
        self.assertEqual(web_heat['web_mentions'], 3)


class WebHeatApiTest(unittest.TestCase):
    def test_paper_api_exposes_web_heat_signals(self) -> None:
        store = PaperStore(':memory:')
        try:
            _seed_paper(store)
            now = datetime(2026, 8, 14, tzinfo=UTC)
            store.record_web_heat(
                'paper-web-1',
                {'web_heat_score': 0.87, 'trend_reason': 'HN 讨论', 'trend_topics': ['多模态']},
                as_of=now,
            )
            api = PaperApiService(store)
            payload = api.paper('paper-web-1')
            self.assertIsNotNone(payload)
            self.assertEqual(payload['signals']['web_heat']['web_heat_score'], 0.87)
            self.assertEqual(payload['signals']['web_heat']['trend_topics'], ['多模态'])
        finally:
            store.close()


if __name__ == '__main__':
    unittest.main()
