from __future__ import annotations

import unittest
from datetime import datetime, timezone

from spark_papers.paper_record_merger import merge_paper_records
from spark_papers.models import PaperRecord


class PaperRecordMergerTest(unittest.TestCase):
    def test_merge_is_storage_independent_and_respects_canonical_policy(self) -> None:
        current = _paper(
            title="Canonical title",
            abstract="Canonical abstract",
            subjects=("cs.AI",),
            external_ids={"arxiv_id": "2401.00001"},
            discovery_sources=("arxiv",),
        )
        incoming = _paper(
            title="Enriched title",
            abstract="Enriched abstract",
            subjects=("cs.LG",),
            external_ids={"doi": "10.1000/test"},
            discovery_sources=("openalex",),
            signals={"openalex": {"citation_count": 10}},
        )

        merged = merge_paper_records(
            current,
            incoming,
            "paper-target",
            preserve_canonical=True,
            add_discovery_source=False,
        )

        self.assertEqual(merged.paper_id, "paper-target")
        self.assertEqual(merged.title, current.title)
        self.assertEqual(merged.abstract, current.abstract)
        self.assertEqual(merged.subjects, current.subjects)
        self.assertEqual(merged.external_ids["doi"], "10.1000/test")
        self.assertEqual(merged.discovery_sources, current.discovery_sources)
        self.assertEqual(merged.signals["openalex"]["citation_count"], 10)


def _paper(
    *,
    title: str,
    abstract: str,
    subjects: tuple[str, ...],
    external_ids: dict[str, str],
    discovery_sources: tuple[str, ...],
    signals: dict[str, dict[str, object]] | None = None,
) -> PaperRecord:
    return PaperRecord(
        paper_id="paper-original",
        title=title,
        abstract=abstract,
        authors=("Ada Lovelace",),
        published_at=datetime(2024, 1, 1, tzinfo=timezone.utc),
        updated_at=None,
        subjects=subjects,
        external_ids=external_ids,
        discovery_sources=discovery_sources,
        signals=signals or {},
        admitted=True,
        admission_reason="fixture",
    )


if __name__ == "__main__":
    unittest.main()
