from __future__ import annotations

import tempfile
import unittest
from datetime import datetime, timezone
from unittest.mock import patch

UTC = timezone.utc
from pathlib import Path

from spark_papers.diagnostics import DIAGNOSTIC_LOGGER_NAME
from spark_papers.models import FetchResult
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


class PaginatedArxivSource:
    name = "arxiv"
    from_date = "2026-07-31"
    until_date = "2026-08-12"

    def __init__(self, pages: dict[str | None, FetchResult | Exception]) -> None:
        self.pages = pages
        self.cursors: list[str | None] = []

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        self.cursors.append(cursor)
        result = self.pages[cursor]
        if isinstance(result, Exception):
            raise result
        return result


class PipelineTest(unittest.TestCase):
    def test_paginated_arxiv_sync_filters_non_ai_and_refreshes_once(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            fetched_at = datetime(2026, 8, 12, 18, 0, tzinfo=UTC)
            source = PaginatedArxivSource(
                {
                    None: FetchResult(
                        "arxiv",
                        (
                            _paper("2608.00001", "AI Paper One", "2026-08-10T00:00:00Z"),
                            {
                                **_paper("2608.00002", "Non AI Paper", "2026-08-10T00:00:00Z"),
                                "subjects": ["math.CO"],
                            },
                        ),
                        "page-one",
                        fetched_at,
                        cursor="next-page",
                    ),
                    "next-page": FetchResult(
                        "arxiv",
                        (_paper("2608.00003", "AI Paper Two", "2026-08-11T00:00:00Z"),),
                        "page-two",
                        fetched_at,
                    ),
                }
            )

            with patch.object(store, "refresh_indexes", wraps=store.refresh_indexes) as refresh:
                result = runner.sync_paginated(
                    source,
                    state_name="arxiv_oai",
                    max_pages=10,
                    admitted_only=True,
                    completion_watermark=datetime(2026, 8, 12, tzinfo=UTC),
                )

            self.assertEqual(result["status"], "success")
            self.assertEqual(result["pages"], 2)
            self.assertEqual(result["records"], 2)
            self.assertEqual(result["excluded"], 1)
            self.assertEqual(source.cursors, [None, "next-page"])
            self.assertEqual(store.count(), 2)
            self.assertEqual(refresh.call_count, 1)
            self.assertEqual(
                [row["record_count"] for row in store._connection.execute(
                    "SELECT record_count FROM snapshots WHERE source = 'arxiv_oai' ORDER BY rowid"
                )],
                [1, 1],
            )
            self.assertEqual(store.get_sync_state("arxiv_oai")["cursor"], None)
            self.assertEqual(
                store.get_sync_state("arxiv_oai")["last_success_at"],
                "2026-08-12T18:00:00+00:00",
            )
            self.assertEqual(
                store.get_sync_state("arxiv_oai")["completed_through"],
                "2026-08-12T00:00:00+00:00",
            )
            store.close()

    def test_paginated_arxiv_sync_partial_does_not_refresh_indexes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
                fetched_at = datetime(2026, 8, 12, tzinfo=UTC)
                store.set_sync_state(
                    "arxiv_oai",
                    None,
                    None,
                    None,
                    datetime(2026, 8, 1, tzinfo=UTC),
                    completed_through=datetime(2026, 8, 1, tzinfo=UTC),
                )
                source = PaginatedArxivSource(
                    {
                        None: FetchResult(
                            "arxiv",
                            (_paper("2608.00004", "AI Paper One", "2026-08-10T00:00:00Z"),),
                            "page-one",
                            fetched_at,
                            cursor="next-page",
                        ),
                    }
                )
                with (
                    patch.object(store, "refresh_indexes", wraps=store.refresh_indexes) as refresh,
                    self.assertNoLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR"),
                ):
                    result = runner.sync_paginated(
                        source,
                        state_name="arxiv_oai",
                        max_pages=1,
                        admitted_only=True,
                    )
                self.assertEqual(result["status"], "partial")
                self.assertEqual(refresh.call_count, 0)
                self.assertEqual(store.get_sync_state("arxiv_oai")["cursor"], "next-page")
                self.assertEqual(
                    store.get_sync_state("arxiv_oai")["completed_through"],
                    "2026-08-01T00:00:00+00:00",
                )
            finally:
                store.close()

    def test_paginated_snapshot_keys_do_not_collide_across_windows(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
                fetched_at = datetime(2026, 8, 12, tzinfo=UTC)
                runner.sync_paginated(
                    PaginatedArxivSource(
                        {
                            None: FetchResult(
                                "arxiv",
                                (_paper("2608.00005", "First Window", "2026-08-10T00:00:00Z"),),
                                "first-window",
                                fetched_at,
                            ),
                        }
                    ),
                    state_name="arxiv_oai",
                    admitted_only=True,
                    refresh_indexes=False,
                    window_key="2026-07-31-to-2026-08-01",
                )
                runner.sync_paginated(
                    PaginatedArxivSource(
                        {
                            None: FetchResult(
                                "arxiv",
                                (_paper("2608.00006", "Second Window", "2026-08-11T00:00:00Z"),),
                                "second-window",
                                fetched_at,
                            ),
                        }
                    ),
                    state_name="arxiv_oai",
                    admitted_only=True,
                    refresh_indexes=False,
                    window_key="2026-08-02-to-2026-08-03",
                )

                snapshots = store._connection.execute(
                    "SELECT snapshot_key FROM snapshots WHERE source = 'arxiv_oai' ORDER BY rowid"
                ).fetchall()
                self.assertEqual(len(snapshots), 2)
                self.assertNotEqual(snapshots[0]["snapshot_key"], snapshots[1]["snapshot_key"])
            finally:
                store.close()

    def test_paginated_arxiv_deleted_record_withdraws_existing_paper_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
                runner.sync(
                    StaticSource(
                        "arxiv",
                        (_paper("2608.00007", "Paper To Withdraw", "2026-08-10T00:00:00Z"),),
                    )
                )
                fetched_at = datetime(2026, 8, 12, tzinfo=UTC)
                result = runner.sync_paginated(
                    PaginatedArxivSource(
                        {
                            None: FetchResult(
                                "arxiv",
                                (
                                    {
                                        "arxiv_id": "2608.00007",
                                        "external_id": "2608.00007",
                                        "withdrawn": True,
                                        "deleted_at": "2026-08-12",
                                    },
                                    {
                                        "arxiv_id": "2608.99999",
                                        "external_id": "2608.99999",
                                        "withdrawn": True,
                                        "deleted_at": "2026-08-12",
                                    },
                                ),
                                "deleted-page",
                                fetched_at,
                            ),
                        }
                    ),
                    state_name="arxiv_oai",
                    admitted_only=True,
                )

                paper_id = next(iter(store.find_by_external_ids({"arxiv_id": "2608.00007"})))
                self.assertTrue(store.get(paper_id).withdrawn)
                self.assertEqual(store.count(), 1)
                self.assertEqual(result["withdrawn"], 1)
                self.assertEqual(result["missing_withdrawals"], 1)
            finally:
                store.close()

    def test_paginated_arxiv_sync_resumes_last_successful_page_after_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            fetched_at = datetime(2026, 8, 12, tzinfo=UTC)
            first = PaginatedArxivSource(
                {
                    None: FetchResult(
                        "arxiv",
                        (_paper("2608.00001", "AI Paper One", "2026-08-10T00:00:00Z"),),
                        "page-one",
                        fetched_at,
                        cursor="next-page",
                    ),
                    "next-page": RetryableSourceError("temporary outage"),
                }
            )

            failed = runner.sync_paginated(
                first,
                state_name="arxiv_oai",
                max_pages=10,
                admitted_only=True,
            )
            checkpoint = store.get_sync_state("arxiv_oai")["cursor"]
            resumed = PaginatedArxivSource(
                {
                    "next-page": FetchResult(
                        "arxiv",
                        (_paper("2608.00003", "AI Paper Two", "2026-08-11T00:00:00Z"),),
                        "page-two",
                        fetched_at,
                    ),
                }
            )
            completed = runner.sync_paginated(
                resumed,
                state_name="arxiv_oai",
                max_pages=10,
                admitted_only=True,
            )

            self.assertEqual(failed["status"], "failed")
            self.assertIn("next-page", checkpoint or "")
            self.assertEqual(resumed.cursors, ["next-page"])
            self.assertEqual(completed["status"], "success")
            self.assertEqual(store.count(), 2)
            self.assertEqual(store.get_sync_state("arxiv_oai")["cursor"], None)
            store.close()

    def test_paginated_arxiv_rejection_does_not_advance_checkpoint(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                completed_through = datetime(2026, 8, 1, tzinfo=UTC)
                previous_fetch = datetime(2026, 8, 2, tzinfo=UTC)
                store.set_sync_state(
                    "arxiv_oai",
                    None,
                    "current-page",
                    "previous-snapshot",
                    previous_fetch,
                    completed_through=completed_through,
                    window_from="2026-08-02",
                    window_until="2026-08-12",
                )
                fetched_at = datetime(2026, 8, 12, 18, 0, tzinfo=UTC)
                source = PaginatedArxivSource(
                    {
                        "current-page": FetchResult(
                            "arxiv",
                            (
                                _paper(
                                    "2608.00020",
                                    "Valid Before Rejection",
                                    "2026-08-10T00:00:00Z",
                                ),
                                {},
                            ),
                            "page-with-rejection",
                            fetched_at,
                            cursor="next-page",
                        ),
                    }
                )

                with patch.object(store, "refresh_indexes", wraps=store.refresh_indexes) as refresh:
                    result = SyncRunner(
                        store,
                        SnapshotStore(Path(directory) / "snapshots"),
                    ).sync_paginated(
                        source,
                        state_name="arxiv_oai",
                        max_pages=10,
                        admitted_only=True,
                        completion_watermark=datetime(2026, 8, 12, tzinfo=UTC),
                    )

                state = store.get_sync_state("arxiv_oai")
                snapshot = store._connection.execute(
                    "SELECT status, cursor FROM snapshots WHERE source = 'arxiv_oai'"
                ).fetchone()
                self.assertEqual(result["status"], "failed")
                self.assertEqual(result["rejected"], 1)
                self.assertEqual(result["cursor"], "current-page")
                self.assertEqual(state["cursor"], "current-page")
                self.assertEqual(state["last_success_at"], previous_fetch.isoformat())
                self.assertEqual(state["completed_through"], completed_through.isoformat())
                self.assertEqual(snapshot["status"], "failed")
                self.assertEqual(snapshot["cursor"], "current-page")
                self.assertEqual(refresh.call_count, 0)
            finally:
                store.close()

    def test_cross_source_identity_merge_and_idempotent_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            arxiv = StaticSource("arxiv", (_paper("2401.00001v2", "A Stable Paper", "2024-01-02T00:00:00Z"),))
            hf = StaticSource(
                "huggingface",
                (
                    _paper(
                        "2401.00001",
                        "A Stable Paper",
                        "2024-01-02T00:00:00Z",
                        source_fields={
                            "signals": {"huggingface": {"heat": 7}},
                            "metadata": {"github_url": "https://github.com/example/research"},
                        },
                    ),
                ),
            )

            github = StaticSource(
                "github",
                (
                    _paper(
                        "2401.00001",
                        "Repository Name",
                        "2020-01-01T00:00:00Z",
                        source_fields={
                            "subjects": ["cs.CV"],
                            "signals": {"github": {"stars": 12}},
                        },
                    ),
                ),
            )

            first = runner.sync(arxiv)
            second = runner.sync(hf)
            github_result = runner.sync(github)
            repeat = runner.sync(arxiv)

            self.assertEqual(first["status"], "success")
            self.assertEqual(second["records"], 1)
            self.assertEqual(github_result["records"], 1)
            self.assertEqual(repeat["status"], "not_modified")
            self.assertEqual(store.count(), 1)
            paper = store.all_candidates()[0]
            self.assertEqual(paper.external_ids["arxiv_id"], "2401.00001")
            self.assertEqual(set(paper.discovery_sources), {"arxiv", "huggingface"})
            self.assertEqual(paper.title, "A Stable Paper")
            self.assertEqual(paper.published_at, datetime(2024, 1, 2, tzinfo=UTC))
            self.assertEqual(paper.subjects, ("cs.AI",))
            self.assertEqual(paper.signals["huggingface"]["heat"], 7)
            self.assertEqual(paper.signals["github"]["stars"], 12)
            self.assertEqual(
                store.github_candidates(limit=1)[0]["github_url"],
                "https://github.com/example/research",
            )
            store.close()

    def test_existing_database_migrates_enrichment_out_of_discovery_sources(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "papers.sqlite3"
            store = PaperStore(path)
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            runner.sync(
                StaticSource(
                    "arxiv",
                    (_paper("2401.00010", "Discovery Source", "2024-01-02T00:00:00Z"),),
                )
            )
            store._connection.execute(
                "UPDATE papers SET discovery_sources_json = ?",
                ('["arxiv","semantic_scholar","github"]',),
            )
            store._connection.execute(
                "DELETE FROM schema_meta WHERE key = 'discovery_sources_v2'"
            )
            store._connection.commit()
            store.close()

            migrated = PaperStore(path)
            paper = migrated.all_candidates()[0]
            self.assertEqual(paper.discovery_sources, ("arxiv",))
            marker = migrated._connection.execute(
                "SELECT value FROM schema_meta WHERE key = 'discovery_sources_v2'"
            ).fetchone()
            self.assertEqual(marker["value"], "complete")
            migrated.close()

    def test_failure_keeps_last_successful_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
            success = runner.sync(StaticSource("arxiv", (_paper("2401.00002", "A Paper", "2024-01-03T00:00:00Z"),)))
            with self.assertNoLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR"):
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
            result = runner.sync(StaticSource("semantic_scholar", (second,), snapshot_key="two"))
            queued = store._connection.execute("SELECT reason, confidence FROM match_queue").fetchall()
            self.assertEqual(store.count(), 1)
            self.assertEqual(result["unmatched"], 1)
            self.assertTrue(any(row["reason"] == "fuzzy_candidate_requires_review" for row in queued))
            self.assertTrue(all(0.65 <= row["confidence"] <= 1 for row in queued))
            store.close()

    def test_conflicting_exact_identity_is_queued_and_not_counted_as_ingested(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                runner = SyncRunner(store, SnapshotStore(Path(directory) / "snapshots"))
                first = _paper(
                    "2401.00010",
                    "First Identity",
                    "2024-01-04T00:00:00Z",
                    source_fields={"doi": "10.1000/first"},
                )
                second = _paper(
                    "2401.00011",
                    "Second Identity",
                    "2024-01-04T00:00:00Z",
                    source_fields={"doi": "10.1000/second"},
                )
                runner.sync(StaticSource("arxiv", (first, second), snapshot_key="seed"))
                conflict = _paper(
                    "2401.00010",
                    "Conflicting Identity",
                    "2024-01-04T00:00:00Z",
                    source_fields={"doi": "10.1000/second"},
                )

                result = runner.sync(
                    StaticSource("arxiv", (conflict,), snapshot_key="conflict")
                )
                queued = store._connection.execute(
                    "SELECT reason FROM match_queue WHERE reason = 'conflicting_exact_identity'"
                ).fetchall()

                self.assertEqual(result["records"], 0)
                self.assertEqual(result["conflicts"], 1)
                self.assertEqual(store.count(), 2)
                self.assertEqual(len(queued), 1)
            finally:
                store.close()
