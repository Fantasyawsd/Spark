from __future__ import annotations

import unittest
from unittest.mock import patch

from spark_papers.models import FetchResult, utc_now
from spark_papers.normalization import normalize_record
from spark_papers.policy import AiAdmissionPolicy
from spark_papers.sources import (
    GitHubRepositorySource,
    HttpJsonSource,
    HuggingFaceDailySource,
    OpenAlexSource,
    SemanticScholarBatchSource,
    SemanticScholarSource,
)


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


    def test_huggingface_daily_shape_preserves_heat_and_github(self) -> None:
        result = FetchResult(
            source="huggingface",
            records=(
                {
                    "paper": {
                        "id": "2401.00001",
                        "title": "A Daily Paper",
                        "summary": "An abstract.",
                        "authors": [{"name": "Ada"}],
                        "publishedAt": "2024-01-02T00:00:00Z",
                        "githubRepo": "https://github.com/example/research",
                        "githubStars": 12,
                        "upvotes": 9,
                        "submittedOnDailyAt": "2026-08-10T00:00:00Z",
                    },
                    "publishedAt": "2024-01-02T00:00:00Z",
                    "upvotes": 9,
                },
            ),
            raw_payload={},
            fetched_at=utc_now(),
        )
        with patch.object(HttpJsonSource, "fetch", return_value=result):
            mapped = HuggingFaceDailySource(dates=("2026-08-10",), max_pages=1).fetch().records[0]

        paper, _ = normalize_record(
            "huggingface",
            mapped,
            fetched_at=utc_now(),
            policy=AiAdmissionPolicy(),
        )
        self.assertTrue(paper.admitted)
        self.assertEqual(paper.admission_reason, "huggingface_daily")
        self.assertEqual(paper.signals["huggingface"]["heat"], 9)
        self.assertEqual(paper.signals["github"]["stars"], 12)
        self.assertEqual(paper.metadata["github_url"], "https://github.com/example/research")

    def test_semantic_scholar_batch_uses_exact_arxiv_ids(self) -> None:
        payload = [
            {
                "paperId": "S1",
                "title": "A Paper",
                "year": 2024,
                "publicationDate": "2024-01-02",
                "externalIds": {"ArXiv": "2401.00001"},
                "citationCount": 4,
                "influentialCitationCount": 2,
                "referenceCount": 8,
                "authors": [{"name": "Ada"}],
            }
        ]
        with patch("spark_papers.sources._request_json", return_value=(payload, {})):
            result = SemanticScholarBatchSource(("2401.00001",), batch_size=1).fetch()

        self.assertEqual(len(result.records), 1)
        self.assertEqual(result.records[0]["arxiv_id"], "2401.00001")
        self.assertEqual(result.records[0]["signals"]["semantic_scholar"]["citation_count"], 4)

    def test_github_repository_source_maps_metrics(self) -> None:
        repository = {
            "full_name": "example/research",
            "html_url": "https://github.com/example/research",
            "stargazers_count": 12,
            "forks_count": 3,
            "updated_at": "2026-08-10T00:00:00Z",
        }
        with patch(
            "spark_papers.sources._request_json",
            return_value=(repository, {"X-RateLimit-Remaining": "59"}),
        ):
            result = GitHubRepositorySource(
                ({"arxiv_id": "2401.00001", "github_url": repository["html_url"]},)
            ).fetch()

        self.assertEqual(len(result.records), 1)
        self.assertEqual(result.records[0]["arxiv_id"], "2401.00001")
        self.assertEqual(result.records[0]["signals"]["github"]["stars"], 12)
        self.assertEqual(result.records[0]["signals"]["github"]["forks"], 3)
