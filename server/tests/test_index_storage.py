from __future__ import annotations

import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from spark_papers.db_mapper import paper_values
from spark_papers.index_storage import IndexStorage
from spark_papers.models import PaperRecord
from spark_papers.storage_schema import StorageSchemaManager


UTC = timezone.utc


class IndexStorageTest(unittest.TestCase):
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
        self.storage = IndexStorage(
            self.connection,
            timestamp_factory=lambda: self.at,
        )
        self._insert_paper()

    def tearDown(self) -> None:
        self.connection.close()
        self.directory.cleanup()

    def test_refresh_owns_materialized_index_lifecycle(self) -> None:
        self.assertFalse(self.storage.is_ready())

        self.storage.refresh()

        self.assertTrue(self.storage.is_ready())
        latest = self.connection.execute(
            "SELECT paper_id, generated_at FROM latest_index"
        ).fetchone()
        self.assertIsNotNone(latest)
        assert latest is not None
        self.assertEqual(latest["paper_id"], "paper-indexed")
        self.assertEqual(latest["generated_at"], self.at.isoformat())
        self.assertEqual(
            self.connection.execute(
                "SELECT channel_key FROM channel_index"
            ).fetchone()[0],
            "subject:cs.ai",
        )
        self.assertEqual(
            self.connection.execute(
                "SELECT author_key FROM author_index"
            ).fetchone()[0],
            "ada lovelace",
        )
        self.assertEqual(
            self.connection.execute(
                "SELECT venue_key FROM venue_index"
            ).fetchone()[0],
            "icml",
        )
        self.assertEqual(
            {
                row["pool"]
                for row in self.connection.execute(
                    "SELECT pool FROM candidate_index"
                )
            },
            {"all", "quality:0-1y", "trending:0-1y"},
        )

    def test_candidate_failure_preserves_previous_pool_transaction(self) -> None:
        previous_at = self.at - timedelta(days=1)
        self.storage.refresh(previous_at)
        self.connection.execute(
            """CREATE TRIGGER reject_quality_pool
               BEFORE INSERT ON candidate_index
               WHEN NEW.pool LIKE 'quality:%'
               BEGIN
                   SELECT RAISE(ABORT, 'candidate refresh failed');
               END"""
        )
        self.connection.commit()

        with self.assertRaisesRegex(
            sqlite3.IntegrityError,
            "candidate refresh failed",
        ):
            self.storage.refresh(self.at)

        self.assertEqual(
            self.connection.execute(
                "SELECT DISTINCT generated_at FROM latest_index"
            ).fetchone()[0],
            self.at.isoformat(),
        )
        self.assertEqual(
            {
                row["generated_at"]
                for row in self.connection.execute(
                    "SELECT generated_at FROM candidate_index"
                )
            },
            {previous_at.isoformat()},
        )

    def _insert_paper(self) -> None:
        paper = PaperRecord(
            paper_id="paper-indexed",
            title="Indexed AI Paper",
            abstract="Index lifecycle",
            authors=("Ada Lovelace",),
            published_at=self.at - timedelta(days=30),
            updated_at=None,
            subjects=("cs.AI",),
            external_ids={"arxiv_id": "2608.00001"},
            discovery_sources=("arxiv",),
            signals={
                "openalex": {"citation_count": 42},
                "huggingface": {"heat": 7},
            },
            metadata={"venue_name": "ICML"},
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
        self.connection.commit()


if __name__ == "__main__":
    unittest.main()
