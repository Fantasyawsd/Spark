from __future__ import annotations

import math
import unittest
from dataclasses import replace
from datetime import datetime, timezone
from unittest.mock import create_autospec

from spark_papers.anonymous_profile import AnonymousProfile
from spark_papers.models import PaperRecord
from spark_papers.personalized_pool import SimilarPaperRecallPort
from spark_papers.ports import RecommendationRepository
from spark_papers.recommendation import RecommendationEngine, ScoreConfig, score_paper

NOW = datetime(2026, 9, 24, tzinfo=timezone.utc)


def _paper(paper_id: str, subject: str) -> PaperRecord:
    return PaperRecord(
        paper_id=paper_id,
        title=f"Paper {paper_id}",
        abstract=None,
        authors=(f"Author {paper_id}",),
        published_at=NOW,
        updated_at=None,
        subjects=(subject,),
        external_ids={},
        discovery_sources=("arxiv",),
        signals={"openalex": {"citation_count": 10}, "huggingface": {"heat": 4}},
        admitted=True,
    )


def _store(papers: list[PaperRecord]):
    """Keep persistence at the port boundary; execute the real recommendation code."""
    store = create_autospec(RecommendationRepository, instance=True)
    by_id = {paper.paper_id: paper for paper in papers}
    store.get.side_effect = by_id.get

    def candidates(*, read_ids=(), per_pool_limit=500, as_of=None):
        return [paper for paper in papers if paper.paper_id not in read_ids]

    def list_papers(*, subject=None, limit=20, to_date=None, **kwargs):
        matches = [
            paper for paper in papers
            if (subject is None or subject in paper.subjects)
            and (to_date is None or paper.published_at <= to_date)
        ]
        return matches[:limit], None

    store.recommendation_candidates.side_effect = candidates
    store.list_papers.side_effect = list_papers
    store.list_papers_by_keyword.return_value = []
    return store


class RecommendationQualityRegressionTest(unittest.TestCase):
    def setUp(self) -> None:
        self.papers = [_paper("a", "cs.AI"), _paper("z", "cs.LG")]
        self.profile = AnonymousProfile(subjects={"cs.AI": 1.0, "cs.LG": 3.0})
        self.store = _store(self.papers)
        self.recall = create_autospec(SimilarPaperRecallPort, instance=True)
        self.recall.recall.return_value = []

    def engine(self, config: ScoreConfig = ScoreConfig()) -> RecommendationEngine:
        return RecommendationEngine(self.store, config=config, similar_recall=self.recall)

    def test_personalized_items_use_the_selected_papers_preference(self) -> None:
        _, items = self.engine(ScoreConfig(personalized_pool_ratio=1.0)).generate(
            limit=2, seed=1, as_of=NOW, anonymous_profile=self.profile,
        )
        self.assertEqual([item.paper.paper_id for item in items], ["a", "z"])
        expected = {"a": 0.25, "z": 0.75}
        for item in items:
            self.assertEqual(item.pool, "personalized")
            self.assertEqual(item.personalization_score, expected[item.paper.paper_id])
            self.assertEqual(item.personalization_score, item.signals["personalization.preference"])

    def test_recorded_batch_preserves_each_papers_personalization_score(self) -> None:
        _, items = self.engine(ScoreConfig(personalized_pool_ratio=1.0)).generate(
            limit=2, seed=1, as_of=NOW, anonymous_profile=self.profile,
        )
        batch = self.store.save_recommendation_batch.call_args.args[0]
        self.assertEqual(batch.items, tuple(items))
        for item in batch.items:
            self.assertEqual(item.personalization_score, item.signals["personalization.preference"])

    def test_regular_non_personalized_pool_exposes_zero(self) -> None:
        # round(1 * 0.4) == 0: the selected paper still has a preference signal.
        _, items = self.engine().generate(
            limit=1, seed=1, as_of=NOW, anonymous_profile=self.profile,
        )
        self.assertEqual(len(items), 1)
        self.assertNotEqual(items[0].pool, "personalized")
        self.assertGreater(items[0].signals["personalization.preference"], 0.0)
        self.assertEqual(items[0].personalization_score, 0.0)

    def test_tail_fill_non_personalized_pool_exposes_zero(self) -> None:
        # No configured age quotas forces the real tail-fill path without mocks.
        _, items = self.engine(ScoreConfig(age_bucket_targets=())).generate(
            limit=2, seed=1, as_of=NOW, anonymous_profile=self.profile,
        )
        self.assertEqual(len(items), 2)
        self.assertEqual(len({item.paper.paper_id for item in items}), 2)
        for item in items:
            self.assertNotEqual(item.pool, "personalized")
            self.assertGreater(item.signals["personalization.preference"], 0.0)
            self.assertEqual(item.personalization_score, 0.0)

    def test_no_profile_retains_zero_scores(self) -> None:
        _, items = self.engine().generate(limit=2, seed=1, as_of=NOW)
        self.assertEqual(len(items), 2)
        for item in items:
            self.assertEqual(item.personalization_score, 0.0)
            self.assertNotIn("personalization.preference", item.signals)

    def test_disabled_personalization_retains_zero_scores(self) -> None:
        _, items = self.engine(ScoreConfig(personalized_pool_ratio=0.0)).generate(
            limit=2, seed=1, as_of=NOW, anonymous_profile=self.profile,
        )
        self.assertEqual(len(items), 2)
        for item in items:
            self.assertEqual(item.personalization_score, 0.0)
            self.assertNotIn("personalization.preference", item.signals)
        self.recall.recall.assert_not_called()

    def test_seeded_results_match_for_list_and_iterator_history(self) -> None:
        history = ["already-read", "already-read"]
        engine = self.engine()
        batch_a, items_a = engine.generate(limit=2, seed=1, as_of=NOW, read_ids=history)
        batch_b, items_b = engine.generate(limit=2, seed=1, as_of=NOW, read_ids=iter(history))
        self.assertEqual(batch_a, batch_b)
        self.assertEqual(items_a, items_b)

    def test_read_history_is_not_consumed_beyond_5000_items(self) -> None:
        def history():
            for index in range(5000):
                yield f"read-{index}"
            raise AssertionError("read beyond the documented 5000-item cap")

        self.engine().generate(limit=1, seed=1, as_of=NOW, read_ids=history())
        actual = self.store.recommendation_candidates.call_args.kwargs["read_ids"]
        self.assertEqual(actual, {f"read-{index}" for index in range(5000)})

    def test_duplicate_history_ids_do_not_extend_the_input_cap(self) -> None:
        history = (f"read-{index // 2}" for index in range(6000))
        self.engine().generate(limit=1, seed=1, as_of=NOW, read_ids=history)
        actual = self.store.recommendation_candidates.call_args.kwargs["read_ids"]
        self.assertEqual(actual, {f"read-{index}" for index in range(2500)})
        self.assertEqual(next(history), "read-2500")

    def test_huge_external_integer_falls_back_to_valid_signal(self) -> None:
        for invalid in (10 ** 400, -(10 ** 400)):
            with self.subTest(negative=invalid < 0):
                paper = replace(
                    self.papers[0],
                    signals={
                        "openalex": {"citation_count": invalid},
                        "semantic_scholar": {"citation_count": 25},
                    },
                )
                quality, trend, signals = score_paper(paper, [paper], as_of=NOW)
                self.assertTrue(math.isfinite(quality) and math.isfinite(trend))
                self.assertEqual(signals["quality.citation_count"], 1.0)
                _, items = RecommendationEngine(_store([paper])).generate(
                    limit=1, seed=1, as_of=NOW,
                )
                self.assertEqual(len(items), 1)
                self.assertEqual(items[0].quality_score, quality)


if __name__ == "__main__":
    unittest.main()
