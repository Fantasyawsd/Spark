from __future__ import annotations

import unittest
from unittest.mock import patch

from spark_papers.models import FetchResult, utc_now
from spark_papers.sources import HttpJsonSource, OpenAlexSource, SemanticScholarSource


class SourceMappingTest(unittest.TestCase):
    def test_openalex_inverted_index_and_signals_are_normalized(self) -> None:
        result = FetchResult(
            source="openalex",
            records=(
                {
                    "id": "https://openalex.org/W123",
                    "display_name": "A Paper",
                    "publication_date": "2024-01-02",
                    "abstract_inverted_index": {"A": [0], "paper": [1]},
                    "authorships": [{"author": {"display_name": "Ada"}}],
                    "cited_by_count": 0,
                    "topics": [{"id": "https://openalex.org/T1"}],
                },
            ),
            raw_payload={},
            fetched_at=utc_now(),
        )
        with patch.object(HttpJsonSource, "fetch", return_value=result):
            mapped = OpenAlexSource().fetch().records[0]
        self.assertEqual(mapped["abstract"], "A paper")
        self.assertEqual(mapped["openalex_id"], "W123")
        self.assertEqual(mapped["signals"]["openalex"]["citation_count"], 0)

    def test_semantic_scholar_data_shape_is_supported(self) -> None:
        result = FetchResult(
            source="semantic_scholar",
            records=(
                {
                    "paperId": "S1",
                    "title": "A Paper",
                    "year": 2024,
                    "externalIds": {"ArXiv": "2401.00001", "DOI": "10.1000/test"},
                    "citationCount": 4,
                    "influentialCitationCount": 2,
                    "authors": [{"name": "Ada"}],
                },
            ),
            raw_payload={},
            fetched_at=utc_now(),
        )
        with patch.object(HttpJsonSource, "fetch", return_value=result):
            mapped = SemanticScholarSource().fetch().records[0]
        self.assertEqual(mapped["arxiv_id"], "2401.00001")
        self.assertEqual(mapped["published_at"], "2024-01-01T00:00:00Z")
        self.assertEqual(mapped["signals"]["semantic_scholar"]["citation_count"], 4)
