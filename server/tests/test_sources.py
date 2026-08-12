from __future__ import annotations

import io
import unittest
import urllib.parse
from unittest.mock import patch

from spark_papers.models import FetchResult, utc_now
from spark_papers.normalization import normalize_record
from spark_papers.policy import AiAdmissionPolicy
from spark_papers.sources import (
    ArxivOaiSource,
    encode_arxiv_oai_cursor,
    GitHubRepositorySource,
    HttpJsonSource,
    HuggingFaceDailySource,
    OpenAlexSource,
    SemanticScholarBatchSource,
    SemanticScholarSource,
    RetryableSourceError,
    SourceError,
)


class SourceMappingTest(unittest.TestCase):
    def test_arxiv_oai_uses_absolute_window_then_resumption_token(self) -> None:
        payloads = iter(
            (
                b'''<?xml version="1.0" encoding="UTF-8"?>
                <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
                  <ListRecords><resumptionToken>next-page</resumptionToken></ListRecords>
                </OAI-PMH>''',
                b'''<?xml version="1.0" encoding="UTF-8"?>
                <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
                  <ListRecords><resumptionToken /></ListRecords>
                </OAI-PMH>''',
            )
        )
        urls: list[str] = []

        def open_request(request, timeout):
            urls.append(request.full_url)
            return io.BytesIO(next(payloads))

        source = ArxivOaiSource(
            from_date="2026-07-31",
            until_date="2026-08-12",
            min_interval_seconds=0,
        )
        with patch("spark_papers.sources.urllib.request.urlopen", side_effect=open_request):
            first = source.fetch()
            second = source.fetch(cursor=first.cursor)

        first_query = urllib.parse.parse_qs(urllib.parse.urlparse(urls[0]).query)
        second_query = urllib.parse.parse_qs(urllib.parse.urlparse(urls[1]).query)
        self.assertEqual(first_query["from"], ["2026-07-31"])
        self.assertEqual(first_query["until"], ["2026-08-12"])
        self.assertEqual(first_query["metadataPrefix"], ["arXiv"])
        self.assertEqual(second_query, {"verb": ["ListRecords"], "resumptionToken": ["next-page"]})
        self.assertEqual(second.cursor, None)

    def test_arxiv_oai_defaults_to_current_oai_endpoint(self) -> None:
        self.assertEqual(ArxivOaiSource().endpoint, "https://oaipmh.arxiv.org/oai")

    def test_arxiv_oai_embedded_error_does_not_look_like_completion(self) -> None:
        payload = b'''<?xml version="1.0" encoding="UTF-8"?>
        <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
          <error code="badResumptionToken">The resumption token is invalid.</error>
        </OAI-PMH>'''
        source = ArxivOaiSource(min_interval_seconds=0)

        with patch(
            "spark_papers.sources.urllib.request.urlopen",
            return_value=io.BytesIO(payload),
        ):
            with self.assertRaisesRegex(SourceError, "badResumptionToken"):
                source.fetch(cursor="expired-token")

    def test_arxiv_oai_expired_window_token_replays_the_absolute_window(self) -> None:
        payloads = iter(
            (
                b'''<?xml version="1.0" encoding="UTF-8"?>
                <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
                  <error code="badResumptionToken">The resumption token expired.</error>
                </OAI-PMH>''',
                b'''<?xml version="1.0" encoding="UTF-8"?>
                <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
                  <ListRecords><resumptionToken /></ListRecords>
                </OAI-PMH>''',
            )
        )
        urls: list[str] = []

        def open_request(request, timeout):
            urls.append(request.full_url)
            return io.BytesIO(next(payloads))

        source = ArxivOaiSource(min_interval_seconds=0)
        cursor = encode_arxiv_oai_cursor(
            "2026-07-31",
            "2026-08-12",
            "expired-token",
        )
        with patch("spark_papers.sources.urllib.request.urlopen", side_effect=open_request):
            result = source.fetch(cursor=cursor)

        token_query = urllib.parse.parse_qs(urllib.parse.urlparse(urls[0]).query)
        replay_query = urllib.parse.parse_qs(urllib.parse.urlparse(urls[1]).query)
        self.assertEqual(
            token_query,
            {"verb": ["ListRecords"], "resumptionToken": ["expired-token"]},
        )
        self.assertEqual(replay_query["from"], ["2026-07-31"])
        self.assertEqual(replay_query["until"], ["2026-08-12"])
        self.assertEqual(replay_query["metadataPrefix"], ["arXiv"])
        self.assertEqual(result.cursor, None)

    def test_arxiv_oai_malformed_xml_is_retryable(self) -> None:
        source = ArxivOaiSource(min_interval_seconds=0)

        with patch(
            "spark_papers.sources.urllib.request.urlopen",
            return_value=io.BytesIO(b"<not-closed>"),
        ):
            with self.assertRaisesRegex(RetryableSourceError, "invalid XML"):
                source.fetch()

    def test_arxiv_oai_deleted_record_preserves_identifier(self) -> None:
        payload = b'''<?xml version="1.0" encoding="UTF-8"?>
        <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
          <ListRecords>
            <record>
              <header status="deleted">
                <identifier>oai:arXiv.org:2608.00001</identifier>
                <datestamp>2026-08-12</datestamp>
              </header>
            </record>
          </ListRecords>
        </OAI-PMH>'''
        source = ArxivOaiSource(min_interval_seconds=0)

        with patch(
            "spark_papers.sources.urllib.request.urlopen",
            return_value=io.BytesIO(payload),
        ):
            record = source.fetch().records[0]

        self.assertEqual(record["arxiv_id"], "2608.00001")
        self.assertEqual(record["external_id"], "2608.00001")
        self.assertEqual(record["deleted_at"], "2026-08-12")
        self.assertTrue(record["withdrawn"])

    def test_arxiv_oai_record_builds_reading_urls_from_the_stable_id(self) -> None:
        payload = b'''<?xml version="1.0" encoding="UTF-8"?>
        <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/"
                 xmlns:arXiv="http://arxiv.org/OAI/arXiv/">
          <ListRecords>
            <record>
              <header>
                <identifier>oai:arXiv.org:2608.00021</identifier>
                <datestamp>2026-08-12</datestamp>
              </header>
              <metadata>
                <arXiv:arXiv>
                  <arXiv:id>2608.00021</arXiv:id>
                  <arXiv:created>2026-08-11</arXiv:created>
                  <arXiv:updated>2026-08-12</arXiv:updated>
                  <arXiv:title>Reading Links</arXiv:title>
                  <arXiv:abstract>Abstract</arXiv:abstract>
                  <arXiv:authors>
                    <arXiv:author>
                      <arXiv:keyname>Lovelace</arXiv:keyname>
                      <arXiv:forenames>Ada</arXiv:forenames>
                    </arXiv:author>
                  </arXiv:authors>
                  <arXiv:categories>cs.AI</arXiv:categories>
                </arXiv:arXiv>
              </metadata>
            </record>
          </ListRecords>
        </OAI-PMH>'''
        source = ArxivOaiSource(min_interval_seconds=0)

        with patch(
            "spark_papers.sources.urllib.request.urlopen",
            return_value=io.BytesIO(payload),
        ):
            record = source.fetch().records[0]

        self.assertEqual(record["metadata"]["abs_url"], "https://arxiv.org/abs/2608.00021")
        self.assertEqual(record["metadata"]["pdf_url"], "https://arxiv.org/pdf/2608.00021")

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
