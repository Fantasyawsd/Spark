from __future__ import annotations

import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from spark_papers.anonymous_profile import AnonymousProfile
from spark_papers.pipeline import SnapshotStore, SyncRunner
from spark_papers.recommendation import RecommendationEngine, ScoreConfig
from spark_papers.sources import StaticSource
from spark_papers.storage import PaperStore

UTC = timezone.utc
NOW = datetime(2026, 8, 14, tzinfo=UTC)


def _seed(store: PaperStore, snapshot_dir: Path) -> None:
    records = (
        {
            'arxiv_id': '2608.00100',
            'title': '多模态扩散模型',
            'abstract': '生成式建模',
            'authors': [{'name': 'Author A'}],
            'published_at': NOW.isoformat(),
            'subjects': ['cs.LG'],
            'signals': {'openalex': {'citation_count': 10}, 'huggingface': {'heat': 5}},
        },
        {
            'arxiv_id': '2608.00101',
            'title': 'Database Indexes',
            'abstract': 'systems',
            'authors': [{'name': 'Author B'}],
            'published_at': NOW.isoformat(),
            'subjects': ['cs.DB'],
            'signals': {'openalex': {'citation_count': 8}, 'huggingface': {'heat': 3}},
        },
    )
    SyncRunner(store, SnapshotStore(snapshot_dir)).sync(StaticSource('arxiv', records))


class PersonalizationScoreExposureTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.store = PaperStore(Path(self.directory.name) / 'papers.sqlite3')
        _seed(self.store, Path(self.directory.name) / 'snap')

    def tearDown(self) -> None:
        self.store.close()
        self.directory.cleanup()

    def test_personalized_pool_item_carries_preference(self) -> None:
        engine = RecommendationEngine(self.store)
        _, items = engine.generate(
            limit=4,
            seed=11,
            as_of=NOW,
            anonymous_profile=AnonymousProfile(keywords={'多模态': 2.0}, subjects={'cs.LG': 2.0}),
        )
        personalized = [item for item in items if item.pool == 'personalized']
        self.assertTrue(personalized)
        self.assertGreater(personalized[0].personalization_score, 0.0)
        self.assertIn('personalization.preference', personalized[0].signals)
        for item in items:
            if item.pool != 'personalized':
                self.assertEqual(item.personalization_score, 0.0)

    def test_without_profile_all_items_have_zero_preference(self) -> None:
        engine = RecommendationEngine(self.store)
        _, items = engine.generate(limit=4, seed=11, as_of=NOW)
        for item in items:
            self.assertEqual(item.personalization_score, 0.0)
            self.assertNotIn('personalization.preference', item.signals)


class BatchVersionTraceabilityTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.store = PaperStore(Path(self.directory.name) / 'papers.sqlite3')
        _seed(self.store, Path(self.directory.name) / 'snap')

    def tearDown(self) -> None:
        self.store.close()
        self.directory.cleanup()

    def test_same_seed_different_score_versions_produce_distinct_batches(self) -> None:
        v3 = RecommendationEngine(self.store, config=ScoreConfig(version='score.v3'))
        v4 = RecommendationEngine(self.store)
        batch_v3, _ = v3.generate(limit=2, seed=7, as_of=NOW)
        batch_v4, _ = v4.generate(limit=2, seed=7, as_of=NOW)
        self.assertNotEqual(batch_v3, batch_v4)
        versions = {
            row['batch_id']: row['score_version']
            for row in self.store._connection.execute(
                'SELECT batch_id, score_version FROM recommendation_batches'
            ).fetchall()
        }
        self.assertEqual(versions[batch_v3], 'score.v3')
        self.assertEqual(versions[batch_v4], 'score.v4')


if __name__ == '__main__':
    unittest.main()
