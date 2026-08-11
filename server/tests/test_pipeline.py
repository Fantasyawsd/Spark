from __future__ import annotations

import tempfile
import unittest
from datetime import datetime, timezone

UTC = timezone.utc
from pathlib import Path

from spark_papers.pipeline import SnapshotStore, SyncRunner
from spark_papers.sources import RetryableSourceError, SourceAdapter, StaticSource
from spark_papers.storage import PaperStore


def _paper(arxiv_id: str, title: str, published_at: str, *, source_fields: dict | None = None) -> dict:
    return {
        "arxiv_id": arxiv_id,
        "external_id": arxiv_id,
        "title": title,
        "abstract": f"Abstract for {title}",
        "authors": [{"name": "Ada Lovelace"}],
        "published_at": published_at,
        "subjects": ["cs.AI"],
        **(source_fields or {}),
    }


class FailingSource:
    name = "arxiv"

    def fetch(self, *, etag: str | None = None, cursor: str | None = None):
        raise RetryableSourceError("temporary outage")


class PipelineTest(unittest.TestCase):
    def test_cross_source_identity_merge_and_idempotent_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            arxiv = StaticSource("arxiv", (_paper("2401.00001v2", "A Stable Paper", "2024-01-02T00:00:00Z"),))
            hf = StaticSource(
                "huggingface",
                (_paper("2401.00001", "A Stable Paper", "2024-01-02T00:00:00Z", source_fields={"signals": {"huggingface": {"heat": 7}}}),),
            )

            first = runner.sync(arxiv)
            second = runner.sync(hf)
            repeat = runner.sync(arxiv)

            self.assertEqual(first["status"], "success")
            self.assertEqual(second["records"], 1)
            self.assertEqual(repeat["status"], "not_modified")
            self.assertEqual(store.count(), 1)
            paper = store.all_candidates()[0]
            self.assertEqual(paper.external_ids["arxiv_id"], "2401.00001")
            self.assertEqual(set(paper.discovery_sources), {"arxiv", "huggingface"})
            self.assertEqual(paper.signals["huggingface"]["heat"], 7)
            store.close()

    def test_failure_keeps_last_successful_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            success = runner.sync(StaticSource("arxiv", (_paper("2401.00002", "A Paper", "2024-01-03T00:00:00Z"),)))
            failure = runner.sync(FailingSource())
            self.assertEqual(success["status"], "success")
            self.assertEqual(failure["status"], "failed")
            self.assertEqual(failure["retained_snapshot"], success["snapshot"])
            self.assertEqual(store.count(), 1)
            store.close()

    def test_non_ai_record_is_stored_but_excluded_from_candidates(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            record = _paper("2401.00003", "Physics", "2024-01-04T00:00:00Z")
            record["subjects"] = ["physics.optics"]
            runner.sync(StaticSource("arxiv", (record,)))
            self.assertEqual(store.count(), 1)
            self.assertEqual(store.all_candidates(), [])
            store.close()

    def test_fuzzy_identity_is_queued_without_automatic_merge(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            first = _paper("", "A Reliable Identity Paper", "2024-01-04T00:00:00Z")
            first.pop("arxiv_id")
            first.pop("external_id")
            second = {**first, "title": "A Reliable Identity Paper: Extended", "published_at": "2024-01-04T00:00:00Z"}
            runner.sync(StaticSource("arxiv", (first,), snapshot_key="one"))
            runner.sync(StaticSource("semantic_scholar", (second,), snapshot_key="two"))
            queued = store._connection.execute("SELECT reason, confidence FROM match_queue").fetchall()
            self.assertEqual(store.count(), 2)
            self.assertTrue(any(row["reason"] == "fuzzy_candidate_requires_review" for row in queued))
            self.assertTrue(all(0.65 <= row["confidence"] <= 1 for row in queued))
            store.close()
