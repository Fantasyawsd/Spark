from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone

from spark_papers.anonymous_profile import AnonymousProfile
from spark_papers.models import PaperRecord
from spark_papers.personalized_pool import (
    PersonalizedPoolConfig,
    TitleKeywordSimilarityRecall,
    build_personalized_candidates,
)
from spark_papers.recommendation import RecommendationEngine, ScoreConfig
from spark_papers.storage import PaperStore

UTC = timezone.utc
NOW = datetime(2026, 8, 14, tzinfo=UTC)


def _ingest(
    store: PaperStore,
    paper_id: str,
    *,
    title: str,
    abstract: str = "",
    subjects: tuple[str, ...] = ("cs.AI",),
    venue: str | None = None,
    admitted: bool = True,
    withdrawn: bool = False,
    days_old: int = 1,
) -> PaperRecord:
    paper = PaperRecord(
        paper_id=paper_id,
        title=title,
        abstract=abstract,
        authors=(f"Author {paper_id}",),
        published_at=NOW - timedelta(days=days_old),
        updated_at=None,
        subjects=subjects,
        external_ids={"test": paper_id},
        discovery_sources=("test",),
        signals={"openalex": {"citation_count": 10}},
        metadata={"venue_name": venue} if venue else {},
        admitted=admitted,
        withdrawn=withdrawn,
    )
    store.ingest(
        paper,
        source="test",
        external_id=paper_id,
        raw_payload={"title": title},
        fetched_at=NOW,
    )
    return paper


class RecordingSimilarRecall:
    def __init__(self, results: dict[str, list[str]]) -> None:
        self.results = results
        self.calls: list[tuple[str, int]] = []

    def recall(
        self,
        paper_id: str,
        limit: int,
        as_of: datetime | None = None,
    ) -> list[str]:
        self.calls.append((paper_id, limit))
        return self.results.get(paper_id, [])


class PersonalizedPoolTest(unittest.TestCase):
    def setUp(self) -> None:
        self.store = PaperStore(":memory:")

    def tearDown(self) -> None:
        self.store.close()

    def test_subject_keyword_and_venue_recall_are_deduplicated(self) -> None:
        _ingest(
            self.store,
            "shared",
            title="Graph Transformers",
            abstract="A retrieval system",
            subjects=("cs.LG",),
            venue="NeurIPS",
        )
        _ingest(self.store, "keyword", title="Efficient RETRIEVAL", subjects=("cs.IR",))
        _ingest(self.store, "venue", title="Vision", subjects=("cs.CV",), venue="NeurIPS")

        result = build_personalized_candidates(
            self.store,
            AnonymousProfile(
                subjects={"cs.LG": 1.0},
                keywords={"retrieval": 1.0},
                venues={"NeurIPS": 1.0},
            ),
            as_of=NOW,
        )

        self.assertEqual({paper.paper_id for paper in result}, {"shared", "keyword", "venue"})
        self.assertEqual(len(result), 3)
        self.assertEqual(
            [paper.paper_id for paper in self.store.list_papers_by_keyword("RETRIEVAL", limit=10)],
            ["shared", "keyword"],
        )

    def test_excludes_withdrawn_and_unadmitted_papers(self) -> None:
        _ingest(self.store, "good", title="Good", subjects=("cs.LG",))
        _ingest(self.store, "withdrawn", title="Gone", subjects=("cs.LG",), withdrawn=True)
        _ingest(self.store, "unadmitted", title="Pending", subjects=("cs.LG",), admitted=False)

        result = build_personalized_candidates(
            self.store,
            AnonymousProfile(subjects={"cs.LG": 1.0}),
            as_of=NOW,
        )

        self.assertEqual([paper.paper_id for paper in result], ["good"])

    def test_weight_key_and_total_limits_apply(self) -> None:
        _ingest(self.store, "high", title="High", subjects=("cs.HI",))
        _ingest(self.store, "second", title="Second", subjects=("cs.SEC",))
        _ingest(self.store, "low", title="Low", subjects=("cs.LO",))

        result = build_personalized_candidates(
            self.store,
            AnonymousProfile(subjects={"cs.SEC": 0.8, "cs.HI": 1.0, "cs.LO": 0.04}),
            PersonalizedPoolConfig(max_subjects=2, min_weight=0.05, max_total=1),
            as_of=NOW,
        )

        self.assertEqual([paper.paper_id for paper in result], ["high"])

    def test_similar_port_uses_first_three_subject_papers_and_skips_unknown(self) -> None:
        for index in range(4):
            _ingest(
                self.store,
                f"seed-{index}",
                title=f"Seed {index}",
                subjects=("cs.LG",),
                days_old=index + 1,
            )
        _ingest(self.store, "similar", title="Similar", subjects=("cs.CV",))
        recall = RecordingSimilarRecall({"seed-0": ["unknown", "similar"]})

        result = build_personalized_candidates(
            self.store,
            AnonymousProfile(subjects={"cs.LG": 1.0}),
            as_of=NOW,
            similar_recall=recall,
        )

        self.assertEqual(recall.calls, [("seed-0", 8), ("seed-1", 8), ("seed-2", 8)])
        self.assertIn("similar", {paper.paper_id for paper in result})

    def test_title_keyword_similarity_prioritizes_subject_then_overlap(self) -> None:
        _ingest(
            self.store,
            "target",
            title="Graph Neural Retrieval",
            abstract="representation models",
            subjects=("cs.LG",),
        )
        _ingest(
            self.store,
            "same",
            title="Graph Representation Models",
            subjects=("cs.LG",),
            days_old=2,
        )
        _ingest(
            self.store,
            "overlap",
            title="Graph Neural Retrieval Representation Models",
            subjects=("cs.IR",),
            days_old=1,
        )
        _ingest(self.store, "none", title="Database Indexes", subjects=("cs.LG",), days_old=3)

        recalled = TitleKeywordSimilarityRecall(self.store).recall("target", limit=3)

        self.assertEqual(recalled[0], "same")
        self.assertEqual(recalled[1], "none")
        self.assertNotIn("target", recalled)

    def test_generate_merges_profile_candidates_before_scoring(self) -> None:
        _ingest(
            self.store,
            "profile-paper",
            title="Personalized Retrieval",
            subjects=("cs.IR",),
        )
        self.store.recommendation_candidates = lambda **kwargs: []  # type: ignore[method-assign]
        engine = RecommendationEngine(self.store, similar_recall=RecordingSimilarRecall({}))

        _, items = engine.generate(
            limit=1,
            seed=7,
            as_of=NOW,
            anonymous_profile=AnonymousProfile(keywords={"personalized": 1.0}),
        )

        self.assertEqual([item.paper.paper_id for item in items], ["profile-paper"])

    def test_generate_uses_personalized_pool_with_quota_limit(self) -> None:
        for index in range(8):
            _ingest(
                self.store,
                f"personal-{index}",
                title=f"Topic{index} Research",
                subjects=(f"cs.X{index}",),
                days_old=index + 1,
            )
        profile = AnonymousProfile(
            keywords={f"topic{index}": float(8 - index) for index in range(8)}
        )

        _, items = RecommendationEngine(
            self.store,
            similar_recall=RecordingSimilarRecall({}),
        ).generate(limit=5, seed=11, as_of=NOW, anonymous_profile=profile)

        personalized = [item for item in items if item.pool == "personalized"]
        self.assertTrue(personalized)
        self.assertLessEqual(len(personalized), round(5 * 0.4))
        self.assertTrue(
            all("personalization.preference" in item.signals for item in personalized)
        )

    def test_higher_preference_is_selected_more_often(self) -> None:
        _ingest(self.store, "high", title="HighPreference", subjects=("cs.HI",))
        _ingest(self.store, "low", title="LowPreference", subjects=("cs.LO",))
        profile = AnonymousProfile(keywords={"highpreference": 10.0, "lowpreference": 0.1})
        engine = RecommendationEngine(
            self.store,
            config=ScoreConfig(personalized_pool_ratio=1.0),
            similar_recall=RecordingSimilarRecall({}),
        )
        selected = [
            engine.generate(limit=1, seed=seed, as_of=NOW, anonymous_profile=profile)[1][0].paper.paper_id
            for seed in range(40)
        ]

        self.assertGreater(selected.count("high"), selected.count("low"))
        self.assertTrue(
            all(
                engine.generate(limit=1, seed=seed, as_of=NOW, anonymous_profile=profile)[1][0].pool
                == "personalized"
                for seed in range(3)
            )
        )

    def test_zero_personalized_ratio_matches_no_profile_behavior(self) -> None:
        _ingest(self.store, "one", title="One", subjects=("cs.AI",))
        _ingest(self.store, "two", title="Two", subjects=("cs.LG",), days_old=2)
        engine = RecommendationEngine(
            self.store,
            config=ScoreConfig(personalized_pool_ratio=0.0),
            similar_recall=RecordingSimilarRecall({}),
        )

        batch_without, items_without = engine.generate(limit=2, seed=9, as_of=NOW)
        batch_with, items_with = engine.generate(
            limit=2,
            seed=9,
            as_of=NOW,
            anonymous_profile=AnonymousProfile(keywords={"one": 1.0}),
        )

        self.assertEqual(batch_with, batch_without)
        self.assertEqual(
            [item.paper.paper_id for item in items_with],
            [item.paper.paper_id for item in items_without],
        )
        self.assertTrue(all(item.pool != "personalized" for item in items_with))
        self.assertTrue(
            all("personalization.preference" not in item.signals for item in items_with)
        )

    def test_as_of_upper_bound_excludes_future_papers(self) -> None:
        _ingest(self.store, "past", title="Past", subjects=("cs.LG",))
        future = PaperRecord(
            paper_id="future",
            title="Future",
            abstract="",
            authors=("Author future",),
            published_at=NOW + timedelta(days=1),
            updated_at=None,
            subjects=("cs.LG",),
            external_ids={"test": "future"},
            discovery_sources=("test",),
            admitted=True,
        )
        self.store.ingest(
            future,
            source="test",
            external_id="future",
            raw_payload={"title": "Future"},
            fetched_at=NOW,
        )

        result = build_personalized_candidates(
            self.store,
            AnonymousProfile(subjects={"cs.LG": 1.0}),
            as_of=NOW,
        )

        self.assertEqual([paper.paper_id for paper in result], ["past"])

    def test_keyword_like_escapes_wildcards(self) -> None:
        _ingest(self.store, "plain", title="Growth 100% year", subjects=("cs.AI",))

        matched = self.store.list_papers_by_keyword("100%", limit=10, to_date=NOW)
        self.assertEqual([paper.paper_id for paper in matched], ["plain"])

        matched = self.store.list_papers_by_keyword("%", limit=10, to_date=NOW)
        self.assertEqual([paper.paper_id for paper in matched], ["plain"])

        matched = self.store.list_papers_by_keyword("_", limit=10, to_date=NOW)
        self.assertEqual(matched, [])


if __name__ == "__main__":
    unittest.main()
