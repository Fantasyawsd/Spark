from __future__ import annotations

import hashlib
import json
import unittest
from dataclasses import replace
from datetime import timedelta
from pathlib import Path

from spark_papers.anonymous_profile import AnonymousProfile
from spark_papers.dto import recommendation_to_api
from spark_papers.recommendation import RecommendationEngine, ScoreConfig, score_paper
from spark_papers.recommendation_scoring import score_candidates
from tests.test_recommendation_quality_regressions import NOW, _paper, _store


class EmptyRecall:
    def recall(self, paper_id, limit, as_of=None):
        return []


def _corpus():
    return [replace(
        _paper(f"paper-{index:03d}", ("cs.AI", "cs.LG", "cs.CV")[index % 3]),
        published_at=NOW - timedelta(days=(30, 500, 1400, 3000)[index % 4]),
        signals={
            "openalex": {"citation_count": index * 11, "citation_velocity": index / 10},
            "huggingface": {"heat": 15 - index},
            "github": {"stars": index * 100},
        },
    ) for index in range(12)]


class ScoringPathTest(unittest.TestCase):
    def test_single_and_batch_paths_agree_for_multisubject_p99(self):
        # One outlier in a small group has a different cap from the union P99.
        papers = [replace(
            _paper(f"p-{i}", "cs.AI"),
            signals={"openalex": {"citation_count": i + 1}},
        ) for i in range(200)]
        papers.append(replace(
            _paper("outlier", "cs.CV"),
            signals={"openalex": {"citation_count": 1_000_000}},
        ))
        target = replace(_paper("target", "cs.AI"), subjects=("cs.AI", "cs.CV"))
        papers.append(target)
        batch = score_candidates(papers, ScoreConfig(), NOW)
        for entry in batch:
            with self.subTest(paper=entry.paper.paper_id):
                self.assertEqual(
                    score_paper(entry.paper, iter(papers), as_of=NOW),
                    (entry.quality, entry.trend, entry.signals),
                )
        self.assertLess(batch[-1].signals["quality.citation_count"], 0.2)

    def test_generator_population_is_consumed_once(self):
        papers = _corpus()
        self.assertEqual(
            score_candidates(iter(papers), ScoreConfig(), NOW),
            score_candidates(papers, ScoreConfig(), NOW),
        )

    def test_missing_zero_and_invalid_signals_remain_distinct(self):
        papers = [
            replace(_paper("missing", "cs.AI"), signals={}),
            replace(_paper("zero", "cs.AI"), signals={"github": {"stars": 0}}),
            replace(_paper("invalid", "cs.AI"), signals={"github": {"stars": 10 ** 400}}),
        ]
        scores = score_candidates(papers, ScoreConfig(), NOW)
        self.assertNotIn("quality.github_stars", scores[0].signals)
        self.assertEqual(scores[1].signals["quality.github_stars"], 0.0)
        self.assertNotIn("quality.github_stars", scores[2].signals)

    def test_target_without_comparison_group_has_no_comparable_citations(self):
        target = _paper("target", "cs.CV")
        _, _, signals = score_paper(target, [_paper("other", "cs.AI")], as_of=NOW)
        self.assertNotIn("quality.citation_count", signals)

    def test_empty_batch_stays_empty(self):
        self.assertEqual(score_candidates([], ScoreConfig(), NOW), [])

    def test_keyword_profile_respects_repository_time_contract(self):
        repository = _store(_corpus())
        engine = RecommendationEngine(repository, similar_recall=EmptyRecall())
        engine.generate(
            seed=1, as_of=NOW,
            anonymous_profile=AnonymousProfile(keywords={"transformer": 1.0}),
        )
        repository.list_papers_by_keyword.assert_called_once_with(
            "transformer", limit=50, to_date=NOW,
        )

    def test_empty_repository_does_not_persist_an_empty_batch(self):
        repository = _store([])
        _, items = RecommendationEngine(repository).generate(seed=1, as_of=NOW)
        self.assertEqual(items, [])
        repository.save_recommendation_batch.assert_not_called()


class SeededBehaviorContractTest(unittest.TestCase):
    def test_legacy_seeded_outputs_are_preserved(self):
        path = Path(__file__).parent / "fixtures/recommendation_structure_v4.json"
        golden = {case["index"]: case for case in json.loads(path.read_text())["cases"]}
        profile = AnonymousProfile(subjects={"cs.AI": 1.0, "cs.LG": 3.0})
        configs = [ScoreConfig(), ScoreConfig(personalized_pool_ratio=1.0),
                   ScoreConfig(personalized_pool_ratio=0.0), ScoreConfig(age_bucket_targets=())]
        case_index = 0
        for seed in range(25):
            for limit in (1, 5, 10):
                for config in configs:
                    for current_profile in (None, profile):
                        index = case_index
                        case_index += 1
                        if index not in golden:
                            continue
                        with self.subTest(index=index, seed=seed, limit=limit):
                            engine = RecommendationEngine(
                                _store(_corpus()), config=config, similar_recall=EmptyRecall(),
                            )
                            batch, items = engine.generate(
                                limit=limit, seed=seed, as_of=NOW,
                                anonymous_profile=current_profile,
                                read_ids=iter(["paper-001", "paper-001"]),
                            )
                            result = {"batch": batch, "items": [recommendation_to_api(item) for item in items]}
                            encoded = json.dumps(result, sort_keys=True)
                            self.assertEqual(batch, golden[index]["batch"])
                            self.assertEqual([i.paper.paper_id for i in items], golden[index]["paper_ids"])
                            self.assertEqual(hashlib.sha256(encoded.encode()).hexdigest(),
                                             golden[index]["sha256"], msg=encoded)


if __name__ == "__main__":
    unittest.main()
