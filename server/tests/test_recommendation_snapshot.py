from __future__ import annotations

import json
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

from spark_papers.models import FieldProvenance, RecommendationBatch, RecommendationItem
from spark_papers.recommendation_snapshot import recommendation_to_record
from tests.test_recommendation_quality_regressions import NOW, _paper


def sample_batch():
    paper = replace(
        _paper("stored-paper", "cs.AI"),
        abstract="研究摘要", authors=("作者", "Ada"), updated_at=NOW,
        metadata={"venue_name": "NeurIPS", "unknown": None},
        external_ids={"arxiv_id": "2609.00001"},
        provenance=(FieldProvenance(
            field_name="title", source="arxiv", fetched_at=NOW,
            source_updated_at=NOW, evidence={"verified": True},
        ),),
    )
    item = RecommendationItem(
        paper=paper, pool="personalized", age_bucket="0-1y",
        quality_score=1 / 3, trend_score=0.987654321,
        personalization_score=0.123456789, recommendation_weight=0.123456789,
        signals={"personalization.preference": 0.123457, "trend.boost": 1.0},
    )
    return RecommendationBatch("batch-fixture", NOW, "score.v4", 7, (item,))


def legacy_fixture():
    path = Path(__file__).parent / "fixtures/recommendation_snapshot_v4.json"
    return json.loads(path.read_text(encoding="utf-8"))


class RecommendationSnapshotTest(unittest.TestCase):
    def test_legacy_fields_rounding_and_utc_timestamps_are_preserved(self):
        self.assertEqual(recommendation_to_record(sample_batch().items[0]), legacy_fixture())

    def test_api_mapper_changes_cannot_change_the_snapshot(self):
        with patch("spark_papers.dto.paper_to_api", return_value={"new_api": True}):
            self.assertEqual(recommendation_to_record(sample_batch().items[0]), legacy_fixture())

    def test_mapping_does_not_mutate_the_domain_item(self):
        item = sample_batch().items[0]
        before = dict(item.signals)
        recommendation_to_record(item)
        self.assertEqual(item.signals, before)
        self.assertEqual(item.quality_score, 1 / 3)


if __name__ == "__main__":
    unittest.main()
