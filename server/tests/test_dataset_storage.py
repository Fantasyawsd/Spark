from __future__ import annotations

import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from spark_papers.dataset_storage import DatasetStorage
from spark_papers.models import PaperRecord
from spark_papers.storage_schema import StorageSchemaManager


UTC = timezone.utc


class DatasetStorageTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.connection = sqlite3.connect(":memory:")
        self.connection.row_factory = sqlite3.Row
        self.at = datetime(2026, 8, 14, 9, 0, tzinfo=UTC)
        StorageSchemaManager(
            self.connection,
            migrations_root=Path(self.directory.name),
        ).initialize(
            paper_schema_version="paper.v1",
            timestamp_factory=lambda: self.at,
        )
        self.storage = DatasetStorage(
            self.connection,
            timestamp_factory=lambda: self.at,
        )

    def tearDown(self) -> None:
        self.connection.close()
        self.directory.cleanup()

    def test_import_lease_and_prefix_listing_are_owned_by_dataset_storage(self) -> None:
        first = self.storage.start_import(
            dataset_key="arxiv-base:first.jsonl",
            source="arxiv",
            source_path="first.jsonl",
            source_size=100,
            source_mtime_ns=10,
            started_at=self.at,
            run_token="first-run",
        )
        self.storage.start_import(
            dataset_key="openalex-top:first.jsonl",
            source="openalex",
            source_path="openalex.jsonl",
            source_size=200,
            source_mtime_ns=20,
            started_at=self.at,
            run_token="openalex-run",
        )

        self.assertEqual(first["status"], "running")
        self.assertEqual(
            [item["dataset_key"] for item in self.storage.list_imports("arxiv-")],
            ["arxiv-base:first.jsonl"],
        )
        with self.assertRaisesRegex(RuntimeError, "dataset import already running"):
            self.storage.start_import(
                dataset_key="arxiv-base:first.jsonl",
                source="arxiv",
                source_path="first.jsonl",
                source_size=100,
                source_mtime_ns=10,
                started_at=self.at + timedelta(seconds=1),
                run_token="competing-run",
            )

    def test_lost_lease_rolls_back_paper_rejection_and_checkpoint(self) -> None:
        dataset_key = "arxiv-base:rollback.jsonl"
        self.storage.start_import(
            dataset_key=dataset_key,
            source="arxiv",
            source_path="rollback.jsonl",
            source_size=100,
            source_mtime_ns=10,
            started_at=self.at,
            run_token="lease-owner",
        )
        paper = PaperRecord(
            paper_id="paper-rollback",
            title="Rollback Paper",
            abstract=None,
            authors=("Ada Lovelace",),
            published_at=self.at,
            updated_at=None,
            subjects=("cs.AI",),
            external_ids={"arxiv_id": "2608.00001"},
            discovery_sources=("arxiv",),
        )

        with self.assertRaisesRegex(RuntimeError, "dataset import lease lost"):
            self.storage.apply_paper_batch(
                dataset_key=dataset_key,
                records=[
                    {
                        "paper": paper,
                        "source": "arxiv",
                        "external_id": "2608.00001",
                        "source_updated_at": None,
                        "raw_payload": {"line_number": 1},
                        "provenance": {},
                    }
                ],
                rejections=[
                    {
                        "line_number": 2,
                        "byte_offset": 80,
                        "error": "invalid record",
                        "payload_excerpt": "broken",
                    }
                ],
                byte_offset=100,
                line_number=2,
                fetched_at=self.at,
                run_token="stale-runner",
            )

        state = self.storage.get_import(dataset_key)
        self.assertIsNotNone(state)
        assert state is not None
        self.assertEqual(state["line_number"], 0)
        self.assertEqual(state["processed_count"], 0)
        self.assertEqual(
            self.connection.execute("SELECT COUNT(*) FROM papers").fetchone()[0],
            0,
        )
        self.assertEqual(
            self.connection.execute(
                "SELECT COUNT(*) FROM dataset_rejections"
            ).fetchone()[0],
            0,
        )


if __name__ == "__main__":
    unittest.main()
