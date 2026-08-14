from __future__ import annotations

import unittest
from datetime import datetime, timezone

from spark_papers.models import PaperRecord
from spark_papers.recommendation import ScoreConfig, score_paper

UTC = timezone.utc


def _paper(paper_id: str, *, signals: dict | None = None) -> PaperRecord:
    return PaperRecord(
        paper_id=paper_id,
        title=f'Paper {paper_id}',
        abstract='Abstract',
        authors=('Ada Lovelace',),
        published_at=datetime(2026, 7, 1, tzinfo=UTC),
        updated_at=None,
        subjects=('cs.AI',),
        external_ids={'arxiv_id': '2608.00099'},
        discovery_sources=('arxiv',),
        signals=signals or {},
        admitted=True,
    )


class WebHeatScoringTest(unittest.TestCase):
    def setUp(self) -> None:
        self.as_of = datetime(2026, 8, 14, 12, 0, tzinfo=UTC)
        self.config = ScoreConfig()

    def test_trend_weights_sum_to_one(self) -> None:
        total = sum(weight for _, weight in self.config.trend_weights)
        self.assertAlmostEqual(total, 1.0, places=9)
        self.assertIn('web_heat', dict(self.config.trend_weights))

    def test_web_heat_raises_trend_score(self) -> None:
        hot = _paper(
            'paper-hot',
            signals={
                'github': {'stars': 100, 'star_velocity': 15.0},
                'web_heat': {'web_heat_score': 1.0},
            },
        )
        cold = _paper(
            'paper-cold',
            signals={'github': {'stars': 100, 'star_velocity': 5.0}},
        )
        mid = _paper(
            'paper-mid',
            signals={'github': {'stars': 100, 'star_velocity': 10.0}},
        )
        candidates = [hot, cold, mid]
        _, hot_trend, hot_signals = score_paper(hot, candidates, self.config, as_of=self.as_of)
        _, cold_trend, cold_signals = score_paper(cold, candidates, self.config, as_of=self.as_of)
        self.assertGreater(hot_trend, cold_trend)
        self.assertIn('trend.web_heat', hot_signals)
        self.assertNotIn('trend.web_heat', cold_signals)

    def test_missing_web_heat_is_not_penalized(self) -> None:
        base = {'github': {'stars': 100, 'star_velocity': 5.0}}
        plain = _paper('paper-plain', signals=base)
        candidates = [plain]
        _, trend, _ = score_paper(plain, candidates, self.config, as_of=self.as_of)
        self.assertGreaterEqual(trend, 0.0)


class BatchVersionTraceabilityTest(unittest.TestCase):
    def test_batches_keep_their_score_versions(self) -> None:
        from spark_papers.storage import PaperStore

        store = PaperStore(':memory:')
        try:
            now = datetime(2026, 8, 14, 12, 0, tzinfo=UTC)
            store.record_batch(
                batch_id='batch-legacy',
                generated_at=now,
                score_version='score.v2',
                sampling_seed=1,
                feature_snapshot={},
                selected_paper_ids=['paper-a'],
            )
            store.record_batch(
                batch_id='batch-current',
                generated_at=now,
                score_version='score.v3',
                sampling_seed=1,
                feature_snapshot={},
                selected_paper_ids=['paper-b'],
            )
            rows = store._connection.execute(
                'SELECT batch_id, score_version FROM recommendation_batches ORDER BY batch_id'
            ).fetchall()
            versions = {row['batch_id']: row['score_version'] for row in rows}
            self.assertEqual(versions['batch-legacy'], 'score.v2')
            self.assertEqual(versions['batch-current'], 'score.v3')
        finally:
            store.close()


if __name__ == '__main__':
    unittest.main()
