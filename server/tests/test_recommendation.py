from __future__ import annotations

import tempfile
import unittest
from dataclasses import replace
from datetime import datetime, timedelta, timezone

UTC = timezone.utc
from pathlib import Path

from spark_papers.pipeline import SnapshotStore, SyncRunner
from spark_papers.recommendation import RecommendationEngine, age_bucket, score_paper
from spark_papers.sources import StaticSource
from spark_papers.storage import PaperStore


class RecommendationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.store = PaperStore(Path(self.directory.name) / "papers.sqlite3")
        now = datetime(2026, 8, 11, tzinfo=UTC)
        records = []
        ages = [30, 180, 500, 1000, 1700, 2500, 3000, 30, 500, 1700, 1000, 30]
        for index, age in enumerate(ages):
            record = {
                "arxiv_id": f"2501.{index:05d}",
                "title": f"AI Paper {index}",
                "abstract": "An AI abstract",
                "authors": [{"name": f"Author {index}"}],
                "published_at": (now - timedelta(days=age)).isoformat(),
                "subjects": ["cs.AI" if index % 2 == 0 else "cs.LG"],
                "signals": {
                    "openalex": {"citation_count": index * 10, "citation_velocity": index + 1},
                    "github": {"stars": index * 100, "star_velocity": index + 1},
                    "huggingface": {"heat": 12 - index},
                },
            }
            records.append(record)
        SyncRunner(self.store, SnapshotStore(Path(self.directory.name) / "snapshots")).sync(StaticSource("arxiv", tuple(records)))

    def tearDown(self) -> None:
        self.store.close()
        self.directory.cleanup()

    def test_recommendation_is_deterministic_and_excludes_read_ids(self) -> None:
        engine = RecommendationEngine(self.store)
        now = datetime(2026, 8, 11, 23, 59, 59, tzinfo=UTC)
        batch_one, items_one = engine.generate(
            limit=8,
            read_ids=["paper_does_not_exist"],
            seed=41,
            as_of=now,
        )
        batch_two, items_two = engine.generate(
            limit=8,
            read_ids=["paper_does_not_exist"],
            seed=41,
            as_of=now,
        )
        self.assertEqual(batch_one, batch_two)
        self.assertEqual([item.paper.paper_id for item in items_one], [item.paper.paper_id for item in items_two])
        self.assertEqual(len(items_one), len({item.paper.paper_id for item in items_one}))
        self.assertTrue(all(item.pool in {"high_impact", "trending"} for item in items_one))
        self.assertTrue(
            all(
                item.age_bucket == age_bucket(item.paper.published_at, now)
                for item in items_one
            )
        )
        for previous, current in zip(items_one, items_one[1:]):
            self.assertNotEqual(previous.paper.authors[0], current.paper.authors[0])
            self.assertTrue(set(previous.paper.subjects).isdisjoint(current.paper.subjects))

        read_id = items_one[0].paper.paper_id
        batch_without_read, items_without_read = engine.generate(
            limit=8,
            read_ids=[read_id],
            seed=41,
            as_of=now,
        )
        self.assertNotIn(read_id, {item.paper.paper_id for item in items_without_read})
        self.assertNotEqual(batch_one, batch_without_read)

        batch_with_different_limit, _ = engine.generate(
            limit=7,
            read_ids=["paper_does_not_exist"],
            seed=41,
            as_of=now,
        )
        self.assertNotEqual(batch_one, batch_with_different_limit)

    def test_openalex_outlier_is_not_used_as_a_quality_signal(self) -> None:
        now = datetime(2026, 8, 11, tzinfo=UTC)
        paper = self.store.all_candidates()[0]
        outlier = replace(
            paper,
            signals={
                "openalex": {
                    "citation_count": 10_000_000,
                    "citation_velocity": 100_000,
                    "citation_count_outlier": True,
                }
            },
        )

        quality, _, signals = score_paper(outlier, (outlier,), as_of=now)

        self.assertEqual(quality, 0.0)
        self.assertNotIn("quality.citation_count", signals)
        self.assertNotIn("quality.citation_velocity", signals)

    def test_age_bucket_boundaries_are_mutually_exclusive(self) -> None:
        now = datetime(2026, 8, 11, tzinfo=UTC)
        self.assertEqual(age_bucket(now - timedelta(days=30), now), "0-1y")
        self.assertEqual(age_bucket(now - timedelta(days=365 * 2), now), "1-3y")
        self.assertEqual(age_bucket(now - timedelta(days=365 * 4), now), "3-5y")
        self.assertEqual(age_bucket(now - timedelta(days=365 * 6), now), "5y+")
