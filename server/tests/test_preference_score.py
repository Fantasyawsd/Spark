from __future__ import annotations

import unittest
from datetime import datetime, timezone

from spark_papers.anonymous_profile import AnonymousProfile
from spark_papers.models import PaperRecord
from spark_papers.preference_score import PreferenceScoreConfig, compute_user_preference

UTC = timezone.utc


def _paper(
    *,
    subjects: tuple[str, ...] = ("cs.LG",),
    title: str = "Graph Retrieval",
    abstract: str = "Transformer systems",
    metadata: dict[str, str] | None = None,
) -> PaperRecord:
    return PaperRecord(
        paper_id="paper-1",
        title=title,
        abstract=abstract,
        authors=("Author",),
        published_at=datetime(2026, 1, 1, tzinfo=UTC),
        updated_at=None,
        subjects=subjects,
        external_ids={},
        discovery_sources=("test",),
        metadata=metadata or {},
        admitted=True,
    )


class PreferenceScoreTest(unittest.TestCase):
    def test_combines_three_matching_components(self) -> None:
        profile = AnonymousProfile(
            subjects={"cs.LG": 3.0, "cs.CV": 1.0},
            venues={"NeurIPS": 2.0, "ICML": 2.0},
            keywords={"GRAPH": 2.0, "vision": 2.0},
        )

        score = compute_user_preference(
            _paper(metadata={"venue_name": "NeurIPS"}),
            profile,
        )

        self.assertAlmostEqual(score or 0.0, 0.625)

    def test_partial_subject_and_keyword_matches_are_normalized(self) -> None:
        profile = AnonymousProfile(
            subjects={"cs.LG": 1.0, "cs.CV": 3.0},
            keywords={"graph": 1.0, "retrieval": 1.0, "vision": 2.0},
        )

        score = compute_user_preference(_paper(), profile)

        self.assertAlmostEqual(score or 0.0, (0.25 * 0.5 + 0.5 * 0.3) / 0.8)

    def test_renormalizes_over_only_matching_components(self) -> None:
        config = PreferenceScoreConfig(subject_weight=0.5, venue_weight=0.2, keyword_weight=0.3)
        profile = AnonymousProfile(subjects={"cs.LG": 1.0}, venues={"ICML": 1.0})

        self.assertEqual(compute_user_preference(_paper(), profile, config), 1.0)

    def test_no_matches_returns_none(self) -> None:
        profile = AnonymousProfile(
            subjects={"cs.CV": 1.0},
            venues={"ICML": 1.0},
            keywords={"diffusion": 1.0},
        )

        self.assertIsNone(compute_user_preference(_paper(), profile))

    def test_venue_label_matches_when_name_is_absent(self) -> None:
        profile = AnonymousProfile(venues={"ACL": 3.0, "EMNLP": 1.0})

        score = compute_user_preference(
            _paper(metadata={"venue_label": "ACL"}),
            profile,
        )

        self.assertAlmostEqual(score or 0.0, 0.75)

    def test_chinese_keyword_matches_via_substring(self) -> None:
        profile = AnonymousProfile(keywords={"多模态": 2.0, "扩散": 2.0})
        paper = _paper(
            title="多模态扩散模型",
            abstract="生成式建模",
        )

        score = compute_user_preference(paper, profile)

        self.assertAlmostEqual(score or 0.0, 1.0)

    def test_single_character_keywords_are_ignored(self) -> None:
        profile = AnonymousProfile(keywords={"a": 2.0, "graph": 1.0})
        paper = _paper(title="Graph Retrieval")

        score = compute_user_preference(paper, profile)

        self.assertAlmostEqual(score or 0.0, 1.0)


if __name__ == "__main__":
    unittest.main()
