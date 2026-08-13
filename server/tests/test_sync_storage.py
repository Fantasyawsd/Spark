from __future__ import annotations

import sqlite3
import unittest
from datetime import datetime, timedelta, timezone

from spark_papers.db_mapper import paper_values
from spark_papers.models import PaperRecord
from spark_papers.storage_schema import StorageSchemaManager
from spark_papers.sync_storage import SyncStorage


UTC = timezone.utc


class SyncStorageTest(unittest.TestCase):
    def setUp(self) -> None:
        self.connection = sqlite3.connect(":memory:")
        self.connection.row_factory = sqlite3.Row
        self.at = datetime(2026, 8, 14, 9, 0, tzinfo=UTC)
        StorageSchemaManager(self.connection).initialize(
            paper_schema_version="paper.v1",
            timestamp_factory=lambda: self.at,
        )
        self.storage = SyncStorage(self.connection)

    def tearDown(self) -> None:
        self.connection.close()

    def test_snapshot_is_idempotently_replaced_by_source_and_key(self) -> None:
        self.storage.record_snapshot(
            "arxiv_oai",
            "window:page-1",
            status="failed",
            fetched_at=self.at,
            cursor="first-token",
            record_count=1,
            error="temporary failure",
        )
        completed_at = self.at + timedelta(minutes=1)
        self.storage.record_snapshot(
            "arxiv_oai",
            "window:page-1",
            status="success",
            fetched_at=completed_at,
            etag="etag-2",
            cursor="next-token",
            raw_path="page-1.xml",
            record_count=20,
        )

        rows = self.connection.execute("SELECT * FROM snapshots").fetchall()
        self.assertEqual(len(rows), 1)
        snapshot = rows[0]
        self.assertEqual(snapshot["status"], "success")
        self.assertEqual(snapshot["fetched_at"], completed_at.isoformat())
        self.assertEqual(snapshot["etag"], "etag-2")
        self.assertEqual(snapshot["cursor"], "next-token")
        self.assertEqual(snapshot["raw_path"], "page-1.xml")
        self.assertEqual(snapshot["record_count"], 20)
        self.assertIsNone(snapshot["error"])

    def test_failed_checkpoint_preserves_success_and_completion_watermark(self) -> None:
        first_completion = self.at - timedelta(days=2)
        self.storage.set_state(
            "arxiv_oai",
            "etag-1",
            "first-token",
            "first.xml",
            self.at,
            completed_through=first_completion,
            window_from="2026-08-12",
            window_until="2026-08-13",
        )
        failed_at = self.at + timedelta(hours=1)
        self.storage.set_state(
            "arxiv_oai",
            "etag-2",
            "retry-token",
            "failed.xml",
            failed_at,
            completed_through=first_completion - timedelta(days=1),
            mark_success=False,
        )

        state = self.storage.get_state("arxiv_oai")
        self.assertEqual(state["etag"], "etag-2")
        self.assertEqual(state["cursor"], "retry-token")
        self.assertEqual(state["last_success_at"], self.at.isoformat())
        self.assertEqual(state["last_snapshot_path"], "failed.xml")
        self.assertEqual(state["completed_through"], first_completion.isoformat())
        self.assertEqual(state["window_from"], "2026-08-12")
        self.assertEqual(state["window_until"], "2026-08-13")

        later_completion = self.at + timedelta(days=1)
        self.storage.set_state(
            "arxiv_oai",
            None,
            None,
            "complete.xml",
            later_completion,
            completed_through=later_completion,
        )
        self.assertEqual(
            self.storage.get_state("arxiv_oai")["completed_through"],
            later_completion.isoformat(),
        )

    def test_default_state_and_latest_source_update(self) -> None:
        self.assertEqual(
            self.storage.get_state("unknown"),
            {
                "etag": None,
                "cursor": None,
                "last_success_at": None,
                "last_snapshot_path": None,
                "completed_through": None,
                "window_from": None,
                "window_until": None,
            },
        )
        self.assertIsNone(self.storage.latest_source_update("arxiv"))

        paper = PaperRecord(
            paper_id="paper-sync",
            title="Synchronized Paper",
            abstract=None,
            authors=("Ada Lovelace",),
            published_at=self.at - timedelta(days=30),
            updated_at=None,
            subjects=("cs.AI",),
            external_ids={"arxiv_id": "2608.00001"},
            discovery_sources=("arxiv",),
            admitted=True,
            admission_reason="subject",
        )
        self.connection.execute(
            """INSERT INTO papers(
                   paper_id, title, abstract, authors_json, published_at, updated_at,
                   subjects_json, external_ids_json, discovery_sources_json, signals_json,
                   metadata_json, admitted, admission_reason, withdrawn, created_at,
                   last_seen_at, schema_version
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            paper_values(paper, self.at, self.at),
        )
        earlier = self.at - timedelta(days=2)
        later = self.at - timedelta(days=1)
        self.connection.executemany(
            """INSERT INTO source_observations(
                   source, external_id, paper_id, payload_json,
                   source_updated_at, fetched_at, etag
               ) VALUES (?, ?, ?, '{}', ?, ?, NULL)""",
            (
                ("arxiv", "2608.00001v1", paper.paper_id, earlier.isoformat(), self.at.isoformat()),
                ("arxiv", "2608.00001v2", paper.paper_id, later.isoformat(), self.at.isoformat()),
            ),
        )
        self.connection.commit()

        self.assertEqual(self.storage.latest_source_update("arxiv"), later)


if __name__ == "__main__":
    unittest.main()
