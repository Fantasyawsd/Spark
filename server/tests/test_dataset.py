from __future__ import annotations

import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from spark_papers.dataset import DatasetImporter
from spark_papers.diagnostics import DIAGNOSTIC_LOGGER_NAME
from spark_papers.models import utc_now
from spark_papers.storage import PaperStore


UTC = timezone.utc


def _arxiv_record(arxiv_id: str, *, categories: str = "cs.AI") -> dict:
    return {
        "id": arxiv_id,
        "submitter": "Ada",
        "authors": "Ada Lovelace and Alan Turing",
        "authors_parsed": [["Lovelace", "Ada", ""], ["Turing", "Alan", ""]],
        "title": "  A\n  Real Dataset Paper  ",
        "abstract": "  Real\nabstract.  ",
        "comments": "Accepted at ICML",
        "journal-ref": None,
        "doi": "10.1000/Test",
        "report-no": None,
        "categories": categories,
        "license": "http://arxiv.org/licenses/nonexclusive-distrib/1.0/",
        "versions": [{"version": "v1", "created": "Sun, 1 Apr 2007 13:06:50 GMT"}],
        "update_date": "2009-09-29",
    }


def _write_jsonl(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(record) + "\n" for record in records), encoding="utf-8")


class DatasetImporterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.store = PaperStore(self.root / "papers.sqlite3")

    def tearDown(self) -> None:
        self.store.close()
        self.directory.cleanup()

    def test_arxiv_mapping_preserves_contract_fields(self) -> None:
        source = self.root / "arxiv.jsonl"
        _write_jsonl(source, [_arxiv_record("0704.0047", categories="cs.IR")])

        report = DatasetImporter(self.store, batch_size=1).import_arxiv(source)

        self.assertEqual(report["status"], "completed")
        self.assertEqual(report["processed_count"], 1)
        self.assertEqual(report["imported_count"], 1)
        self.assertLessEqual(report["max_batch_size"], 1)
        paper = self.store.all_candidates()[0]
        self.assertEqual(paper.title, "A Real Dataset Paper")
        self.assertEqual(paper.abstract, "Real abstract.")
        self.assertEqual(paper.authors, ("Ada Lovelace", "Alan Turing"))
        self.assertEqual(paper.published_at, datetime(2007, 4, 1, 13, 6, 50, tzinfo=UTC))
        self.assertEqual(paper.updated_at, datetime(2009, 9, 29, tzinfo=UTC))
        self.assertEqual(paper.external_ids["arxiv_id"], "0704.0047")
        self.assertEqual(paper.external_ids["doi"], "10.1000/test")
        self.assertEqual(paper.subjects, ("cs.IR",))
        self.assertTrue(paper.admitted)
        self.assertEqual(paper.metadata["arxiv"]["comments"], "Accepted at ICML")
        self.assertEqual(paper.metadata["venue_name"], None)
        self.assertEqual(paper.metadata["venue_year"], None)
        self.assertEqual(paper.metadata["pdf_url"], "https://arxiv.org/pdf/0704.0047")
        observation = self.store._connection.execute(
            "SELECT payload_json FROM source_observations WHERE source = 'arxiv'"
        ).fetchone()
        self.assertEqual(json.loads(observation["payload_json"])["line_number"], 1)
        self.assertNotIn("abstract", json.loads(observation["payload_json"]))

    def test_import_resumes_and_records_rejections(self) -> None:
        source = self.root / "resume.jsonl"
        records = [_arxiv_record(f"2401.{index:05d}") for index in range(3)]
        _write_jsonl(source, records[:2])
        with source.open("a", encoding="utf-8") as handle:
            handle.write("{not-json}\n")
            handle.write(json.dumps(records[2]) + "\n")
        with self.assertNoLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR"):
            partial = DatasetImporter(self.store, batch_size=1).import_arxiv(source, max_records=2)
            completed = DatasetImporter(self.store, batch_size=1).import_arxiv(source)
            repeated = DatasetImporter(self.store, batch_size=1).import_arxiv(source)

        self.assertEqual(partial["status"], "running")
        self.assertEqual(partial["processed_count"], 2)
        self.assertEqual(completed["status"], "completed")
        self.assertEqual(completed["processed_count"], 4)
        self.assertEqual(completed["imported_count"], 3)
        self.assertEqual(completed["rejected_count"], 1)
        self.assertEqual(repeated["processed_this_run"], 0)
        self.assertEqual(self.store.count(), 3)
        rejection = self.store._connection.execute(
            "SELECT line_number, error FROM dataset_rejections"
        ).fetchone()
        self.assertEqual(rejection["line_number"], 3)
        self.assertIn("JSONDecodeError", rejection["error"])

    def test_changed_source_cannot_reuse_checkpoint(self) -> None:
        source = self.root / "changed.jsonl"
        _write_jsonl(source, [_arxiv_record("2401.00001"), _arxiv_record("2401.00002")])
        importer = DatasetImporter(self.store, batch_size=1)
        importer.import_arxiv(source, max_records=1)
        with source.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(_arxiv_record("2401.00003")) + "\n")

        with self.assertRaisesRegex(ValueError, "source changed"):
            importer.import_arxiv(source)

    def test_active_import_lease_rejects_concurrent_runner(self) -> None:
        source = self.root / "leased.jsonl"
        _write_jsonl(source, [_arxiv_record("2401.00001")])
        stat = source.stat()
        self.store.start_dataset_import(
            dataset_key="arxiv-base:leased.jsonl",
            source="arxiv",
            source_path=str(source.resolve()),
            source_size=stat.st_size,
            source_mtime_ns=stat.st_mtime_ns,
            started_at=utc_now(),
            run_token="held-by-another-runner",
            lease_seconds=120,
        )

        with self.assertRaisesRegex(RuntimeError, "already running"):
            DatasetImporter(self.store, batch_size=1).import_arxiv(source)

    def test_venue_and_openalex_only_enrich_existing_papers(self) -> None:
        arxiv = self.root / "arxiv.jsonl"
        _write_jsonl(arxiv, [_arxiv_record("2401.00001"), _arxiv_record("2401.00002")])
        importer = DatasetImporter(self.store, batch_size=1)
        importer.import_arxiv(arxiv)
        venue_file = self.root / "venues" / "2024" / "ICML" / "oral.jsonl"
        _write_jsonl(
            venue_file,
            [
                {"id": "2401.00001", "_matched_venue": "ICML", "_matched_label": "oral"},
                {"id": "2401.99999", "_matched_venue": "ICML", "_matched_label": "none"},
            ],
        )
        openalex = self.root / "openalex.jsonl"
        _write_jsonl(
            openalex,
            [
                {
                    "arxiv_id": "2401.00001",
                    "openalex_id": "https://openalex.org/W123",
                    "publication_year": 2024,
                    "cited_by_count": 42,
                    "fwci": 3.5,
                    "via": "arxiv",
                },
                {
                    "arxiv_id": "2401.99999",
                    "openalex_id": "https://openalex.org/W999",
                    "cited_by_count": 10,
                    "fwci": 1.0,
                    "via": "title-match",
                },
            ],
        )

        venue_report = importer.import_venues(venue_file.parents[2])
        openalex_report = importer.import_openalex(openalex)

        self.assertEqual(self.store.count(), 2)
        self.assertEqual(venue_report["imported"], 1)
        self.assertEqual(venue_report["unmatched"], 1)
        self.assertEqual(openalex_report["imported_count"], 1)
        self.assertEqual(openalex_report["unmatched_count"], 1)
        paper_id = self.store.find_by_external_ids({"arxiv_id": "2401.00001"}).pop()
        paper = self.store.get(paper_id)
        self.assertIsNotNone(paper)
        assert paper is not None
        self.assertEqual(paper.metadata["venue_name"], "ICML")
        self.assertEqual(paper.metadata["venue_matches"], ["ICML"])
        self.assertEqual(paper.metadata["venue_label"], "oral")
        self.assertIsNone(paper.metadata["venue_year"])
        self.assertEqual(paper.external_ids["openalex_id"], "W123")
        self.assertEqual(paper.signals["openalex"]["citation_count"], 42)
        self.assertEqual(paper.signals["openalex"]["fwci"], 3.5)
        self.assertEqual(paper.metadata["openalex"]["publication_year"], 2024)
        self.assertEqual({item.source for item in paper.provenance}, {"arxiv", "arxiv_venue", "openalex"})

    def test_recommendation_candidate_query_is_bounded_by_pool_and_age(self) -> None:
        source = self.root / "many.jsonl"
        records = []
        now = datetime(2026, 8, 12, tzinfo=UTC)
        for index in range(120):
            record = _arxiv_record(f"2501.{index:05d}")
            created = now - timedelta(days=(index % 4) * 730 + index)
            record["versions"] = [
                {"version": "v1", "created": created.strftime("%a, %d %b %Y %H:%M:%S GMT")}
            ]
            records.append(record)
        _write_jsonl(source, records)
        DatasetImporter(self.store, batch_size=20).import_arxiv(source)

        candidates = self.store.recommendation_candidates(per_pool_limit=5, as_of=now)

        self.assertLessEqual(len(candidates), 5 * 2 * 4)
        self.assertGreater(len(candidates), 0)
        self.assertGreater(len(self.store.semantic_scholar_candidates(limit=5)), 0)


if __name__ == "__main__":
    unittest.main()
