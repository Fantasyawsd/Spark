from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone

from spark_papers.models import PaperRecord
from spark_papers.star_velocity import compute_star_velocity
from spark_papers.storage import PaperStore

UTC = timezone.utc


def _github_paper(
    stars: int | None,
    *,
    stars_updated_at: datetime | None = None,
    published_at: datetime | None = None,
) -> PaperRecord:
    now = published_at or datetime(2026, 8, 1, tzinfo=UTC)
    signals = {
        "github": {
            "url": "https://github.com/example/repo",
            "stars": stars,
            "stars_updated_at": stars_updated_at.isoformat() if stars_updated_at else None,
        }
    }
    return PaperRecord(
        paper_id="paper-github-1",
        title="Paper With Repository",
        abstract="Abstract",
        authors=("Grace Hopper",),
        published_at=now,
        updated_at=None,
        subjects=("cs.AI",),
        external_ids={"arxiv_id": "2608.00001"},
        discovery_sources=("github",),
        signals=signals,
        metadata={"github_url": "https://github.com/example/repo"},
        admitted=True,
    )


class ComputeStarVelocityTest(unittest.TestCase):
    def test_two_observations_inside_window(self) -> None:
        as_of = datetime(2026, 8, 20, tzinfo=UTC)
        observations = [
            (as_of - timedelta(days=10), 100),
            (as_of - timedelta(days=2), 180),
        ]
        velocity = compute_star_velocity(observations, as_of)
        self.assertEqual(velocity, 10.0)

    def test_single_observation_returns_none(self) -> None:
        as_of = datetime(2026, 8, 20, tzinfo=UTC)
        velocity = compute_star_velocity([(as_of - timedelta(days=1), 100)], as_of)
        self.assertIsNone(velocity)

    def test_observations_outside_window_are_ignored(self) -> None:
        as_of = datetime(2026, 8, 20, tzinfo=UTC)
        observations = [
            (as_of - timedelta(days=40), 100),
            (as_of - timedelta(days=35), 110),
            (as_of - timedelta(days=1), 200),
        ]
        self.assertIsNone(compute_star_velocity(observations, as_of, window_days=30))

    def test_zero_delta_days_returns_none(self) -> None:
        as_of = datetime(2026, 8, 20, tzinfo=UTC)
        same_moment = as_of - timedelta(days=1)
        velocity = compute_star_velocity([(same_moment, 100), (same_moment, 120)], as_of)
        self.assertIsNone(velocity)

    def test_star_loss_clamped_to_zero(self) -> None:
        as_of = datetime(2026, 8, 20, tzinfo=UTC)
        observations = [
            (as_of - timedelta(days=10), 200),
            (as_of - timedelta(days=2), 160),
        ]
        self.assertEqual(compute_star_velocity(observations, as_of), 0.0)

    def test_rejects_non_positive_window(self) -> None:
        as_of = datetime(2026, 8, 20, tzinfo=UTC)
        with self.assertRaises(ValueError):
            compute_star_velocity([(as_of, 1), (as_of, 2)], as_of, window_days=0)


class GithubStarHistoryIngestTest(unittest.TestCase):
    def test_ingest_appends_history_idempotently(self) -> None:
        store = PaperStore(':memory:')
        try:
            now = datetime(2026, 8, 10, tzinfo=UTC)
            observed = datetime(2026, 8, 9, tzinfo=UTC)
            for _ in range(2):
                store.ingest(
                    _github_paper(100, stars_updated_at=observed),
                    source="github",
                    external_id="2608.00001",
                    raw_payload={"stars": 100},
                    fetched_at=now,
                )
            rows = store._connection.execute(
                "SELECT COUNT(*) AS total FROM github_star_history"
            ).fetchone()
            self.assertEqual(rows['total'], 1)
        finally:
            store.close()

    def test_ingest_derives_velocity_from_history(self) -> None:
        store = PaperStore(':memory:')
        try:
            first_observed = datetime(2026, 8, 1, tzinfo=UTC)
            second_observed = datetime(2026, 8, 11, tzinfo=UTC)
            fetched = datetime(2026, 8, 12, tzinfo=UTC)
            store.ingest(
                _github_paper(100, stars_updated_at=first_observed),
                source="github",
                external_id="2608.00001",
                raw_payload={"stars": 100},
                fetched_at=fetched,
            )
            store.ingest(
                _github_paper(160, stars_updated_at=second_observed),
                source="github",
                external_id="2608.00001",
                raw_payload={"stars": 160},
                fetched_at=fetched,
            )
            paper = store.get('paper-github-1')
            self.assertIsNotNone(paper)
            velocity = paper.signals['github'].get('star_velocity')
            self.assertEqual(velocity, 6.0)
            provenance = [
                item for item in paper.provenance
                if item.field_name == 'github_star_velocity'
            ]
            self.assertEqual(len(provenance), 1)
            self.assertEqual(provenance[0].source, 'derived')
        finally:
            store.close()

    def test_ingest_single_observation_leaves_velocity_missing(self) -> None:
        store = PaperStore(':memory:')
        try:
            now = datetime(2026, 8, 12, tzinfo=UTC)
            store.ingest(
                _github_paper(100, stars_updated_at=now),
                source="github",
                external_id="2608.00001",
                raw_payload={"stars": 100},
                fetched_at=now,
            )
            paper = store.get('paper-github-1')
            self.assertIsNotNone(paper)
            self.assertIsNone(paper.signals['github'].get('star_velocity'))
        finally:
            store.close()


if __name__ == '__main__':
    unittest.main()
