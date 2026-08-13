from __future__ import annotations

import unittest

from spark_papers.db_mapper import paper_from_row


def _paper_row(*, published_at: str = "2024-01-01T00:00:00+00:00") -> dict[str, object]:
    return {
        "paper_id": "paper-1",
        "title": "A Paper",
        "abstract": None,
        "authors_json": "[]",
        "published_at": published_at,
        "updated_at": None,
        "subjects_json": "[]",
        "external_ids_json": "{}",
        "discovery_sources_json": "[]",
        "signals_json": "{}",
        "metadata_json": "{}",
        "admitted": 1,
        "admission_reason": "fixture",
        "withdrawn": 0,
        "schema_version": "paper.v1",
    }


class DbMapperTest(unittest.TestCase):
    def test_blank_database_abstract_is_normalized_to_none(self) -> None:
        row = _paper_row()
        row["abstract"] = " \n\t "

        paper = paper_from_row(row, [])

        self.assertIsNone(paper.abstract)

    def test_invalid_published_at_is_rejected_instead_of_fabricated(self) -> None:
        with self.assertRaisesRegex(ValueError, "published_at"):
            paper_from_row(_paper_row(published_at="not-a-time"), [])

    def test_invalid_provenance_fetched_at_is_rejected_instead_of_fabricated(self) -> None:
        provenance = {
            "field_name": "title",
            "source": "arxiv",
            "fetched_at": "not-a-time",
            "source_updated_at": None,
            "evidence_json": "{}",
        }

        with self.assertRaisesRegex(ValueError, "provenance.fetched_at"):
            paper_from_row(_paper_row(), [provenance])


if __name__ == "__main__":
    unittest.main()
