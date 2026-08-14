from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone

from spark_papers.models import PaperRecord
from spark_papers.recommendation import ScoreConfig, score_paper
from spark_papers.trend_boost import BoostConfig, compute_trend_boost

UTC = timezone.utc


def _paper(paper_id: str, *, web_heat: dict | None = None, github: dict | None = None) -> PaperRecord:
    signals: dict = {}
    if github is not None:
        signals['github'] = github
    if web_heat is not None:
        signals['web_heat'] = web_heat
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
        signals=signals,
        admitted=True,
    )


class ComputeTrendBoostTest(unittest.TestCase):
    def setUp(self) -> None:
        self.as_of = datetime(2026, 8, 14, 12, 0, tzinfo=UTC)
        self.config = BoostConfig(window_hours=72.0, half_life_hours=24.0, gain=1.0)

    def test_no_detection_returns_one(self) -> None:
        self.assertEqual(compute_trend_boost(None, self.as_of, self.config), 1.0)

    def test_future_detection_returns_one(self) -> None:
        future = self.as_of + timedelta(hours=1)
        self.assertEqual(compute_trend_boost(future, self.as_of, self.config), 1.0)

    def test_outside_window_returns_one(self) -> None:
        old = self.as_of - timedelta(hours=73)
        self.assertEqual(compute_trend_boost(old, self.as_of, self.config), 1.0)

    def test_zero_age_gets_full_gain(self) -> None:
        self.assertEqual(compute_trend_boost(self.as_of, self.as_of, self.config), 2.0)

    def test_half_life_decay(self) -> None:
        half_life_ago = self.as_of - timedelta(hours=24)
        self.assertAlmostEqual(
            compute_trend_boost(half_life_ago, self.as_of, self.config),
            1.5,
            places=6,
        )

    def test_deterministic(self) -> None:
        detected = self.as_of - timedelta(hours=10)
        self.assertEqual(
            compute_trend_boost(detected, self.as_of, self.config),
            compute_trend_boost(detected, self.as_of, self.config),
        )

    def test_invalid_config_raises(self) -> None:
        with self.assertRaises(ValueError):
            BoostConfig(window_hours=0)
        with self.assertRaises(ValueError):
            BoostConfig(half_life_hours=-1)
        with self.assertRaises(ValueError):
            BoostConfig(gain=-0.5)


class TrendBoostScoringTest(unittest.TestCase):
    def test_hot_paper_gets_higher_trend_score(self) -> None:
        as_of = datetime(2026, 8, 14, 12, 0, tzinfo=UTC)
        github = {'stars': 100, 'star_velocity': 5.0}
        hot = _paper('paper-hot', web_heat={'trend_detected_at': (as_of - timedelta(hours=1)).isoformat()}, github=github)
        cold = _paper('paper-cold', github=github)
        candidates = [hot, cold]
        _, hot_trend, hot_signals = score_paper(hot, candidates, as_of=as_of)
        _, cold_trend, cold_signals = score_paper(cold, candidates, as_of=as_of)
        self.assertGreater(hot_trend, cold_trend)
        self.assertGreater(hot_signals['trend.boost'], 1.0)
        self.assertEqual(cold_signals['trend.boost'], 1.0)

    def test_boost_does_not_affect_quality(self) -> None:
        as_of = datetime(2026, 8, 14, 12, 0, tzinfo=UTC)
        github = {'stars': 100, 'star_velocity': 5.0}
        hot = _paper('paper-hot', web_heat={'trend_detected_at': (as_of - timedelta(hours=1)).isoformat()}, github=github)
        cold = _paper('paper-cold', github=github)
        candidates = [hot, cold]
        hot_quality, _, _ = score_paper(hot, candidates, as_of=as_of)
        cold_quality, _, _ = score_paper(cold, candidates, as_of=as_of)
        self.assertAlmostEqual(hot_quality, cold_quality, places=6)

    def test_old_detection_receives_no_boost(self) -> None:
        as_of = datetime(2026, 8, 14, 12, 0, tzinfo=UTC)
        github = {'stars': 100, 'star_velocity': 5.0}
        stale = _paper(
            'paper-stale',
            web_heat={'trend_detected_at': (as_of - timedelta(hours=100)).isoformat()},
            github=github,
        )
        cold = _paper('paper-cold', github=github)
        candidates = [stale, cold]
        _, stale_trend, stale_signals = score_paper(stale, candidates, as_of=as_of)
        _, cold_trend, _ = score_paper(cold, candidates, as_of=as_of)
        self.assertAlmostEqual(stale_trend, cold_trend, places=6)
        self.assertEqual(stale_signals['trend.boost'], 1.0)


if __name__ == '__main__':
    unittest.main()
