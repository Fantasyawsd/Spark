from __future__ import annotations

import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone
from pathlib import Path

from unittest.mock import patch

from spark_papers.cli import _arxiv_oai_window, _ensure_arxiv_oai_checkpoint, main
from spark_papers.diagnostics import DIAGNOSTIC_LOGGER_NAME
from spark_papers.pipeline import SnapshotStore, SyncRunner
from spark_papers.sources import RetryableSourceError, StaticSource
from spark_papers.storage import PaperStore


UTC = timezone.utc


class FailingExternalSource:
    name = "huggingface"

    def fetch(self, *, etag: str | None = None, cursor: str | None = None):
        raise RetryableSourceError("temporary outage")


class CliTest(unittest.TestCase):
    def test_external_sync_failure_exits_nonzero_without_refreshing_indexes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "papers.sqlite3"
            snapshots = Path(directory) / "snapshots"
            output = io.StringIO()
            argv = [
                "spark-papers",
                "--db",
                str(database),
                "--snapshots",
                str(snapshots),
                "sync-external",
                "--skip-semantic-scholar",
                "--skip-github",
            ]
            with (
                patch("sys.argv", argv),
                patch(
                    "spark_papers.cli.HuggingFaceDailySource",
                    return_value=FailingExternalSource(),
                ),
                patch.object(PaperStore, "refresh_indexes") as refresh_indexes,
                redirect_stdout(output),
                self.assertNoLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR"),
                self.assertRaises(SystemExit) as exit_context,
            ):
                main()

            self.assertEqual(exit_context.exception.code, 1)
            refresh_indexes.assert_not_called()
            report = json.loads(output.getvalue())
            self.assertEqual(report["failed_sources"], ["huggingface"])
            self.assertFalse(report["indexes_refreshed"])

    def test_unexpected_cli_failure_logs_fixed_operation_without_inputs(self) -> None:
        argv = [
            "spark-papers",
            "--db",
            "private-database.sqlite3",
            "sync-json",
            "--source",
            "private-source",
            "--file",
            "private-record.json",
        ]
        error = RuntimeError("token=server-secret paper=private-record")

        with (
            patch("sys.argv", argv),
            patch("spark_papers.cli.PaperStore", side_effect=error),
            self.assertLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR") as logs,
            self.assertRaises(SystemExit) as exit_context,
        ):
            main()

        self.assertEqual(exit_context.exception.code, 1)
        output = "\n".join(logs.output)
        self.assertIn("operation=cli.sync_json", output)
        self.assertIn("type=RuntimeError", output)
        self.assertIn("cli.py", output)
        for secret in (
            "server-secret",
            "private-record",
            "private-source",
            "private-database",
        ):
            self.assertNotIn(secret, output)

    def test_first_arxiv_oai_window_starts_at_latest_arxiv_update(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                SyncRunner(store, SnapshotStore(Path(directory) / "snapshots")).sync(
                    StaticSource(
                        "arxiv",
                        (
                            {
                                "arxiv_id": "2607.00001",
                                "external_id": "2607.00001",
                                "title": "Last Snapshot Paper",
                                "abstract": "Abstract",
                                "authors": [{"name": "Ada"}],
                                "published_at": "2026-07-30T00:00:00Z",
                                "updated_at": "2026-07-31T00:00:00Z",
                                "subjects": ["cs.AI"],
                            },
                        ),
                    )
                )

                window = _arxiv_oai_window(
                    store,
                    from_date=None,
                    until_date=None,
                    now=datetime(2026, 8, 12, 12, 0, tzinfo=UTC),
                )

                self.assertEqual(window, ("2026-07-31", "2026-08-12"))
            finally:
                store.close()

    def test_partial_arxiv_oai_window_comes_from_checkpoint(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                store.set_sync_state(
                    "arxiv_oai",
                    None,
                    json.dumps(
                        {
                            "from": "2026-07-31",
                            "until": "2026-08-12",
                            "token": "next-page",
                        },
                        separators=(",", ":"),
                    ),
                    None,
                    datetime(2026, 8, 12, 12, 0, tzinfo=UTC),
                )
                self.assertEqual(
                    _arxiv_oai_window(
                        store,
                        from_date=None,
                        until_date=None,
                        now=datetime(2026, 8, 12, 18, 0, tzinfo=UTC),
                    ),
                    ("2026-07-31", "2026-08-12"),
                )
            finally:
                store.close()

    def test_partial_arxiv_oai_window_survives_a_damaged_cursor(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                store.set_sync_state(
                    "arxiv_oai",
                    None,
                    "damaged-token",
                    None,
                    datetime(2026, 8, 12, 18, 0, tzinfo=UTC),
                    completed_through=datetime(2026, 7, 30, tzinfo=UTC),
                    window_from="2026-07-31",
                    window_until="2026-08-12",
                )

                self.assertEqual(
                    _arxiv_oai_window(
                        store,
                        from_date=None,
                        until_date=None,
                        now=datetime(2026, 8, 12, 20, 0, tzinfo=UTC),
                    ),
                    ("2026-07-31", "2026-08-12"),
                )
            finally:
                store.close()

    def test_completed_arxiv_oai_window_uses_completion_watermark(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                store.set_sync_state(
                    "arxiv_oai",
                    None,
                    None,
                    None,
                    datetime(2026, 8, 12, 18, 0, tzinfo=UTC),
                    completed_through=datetime(2026, 8, 11, tzinfo=UTC),
                    window_from="2026-07-31",
                    window_until="2026-08-11",
                )

                self.assertEqual(
                    _arxiv_oai_window(
                        store,
                        from_date=None,
                        until_date=None,
                        now=datetime(2026, 8, 12, 20, 0, tzinfo=UTC),
                    ),
                    ("2026-08-11", "2026-08-12"),
                )
            finally:
                store.close()

    def test_arxiv_oai_window_rejects_a_future_until_date(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                with self.assertRaisesRegex(ValueError, "2026-08-13"):
                    _arxiv_oai_window(
                        store,
                        from_date="2026-08-12",
                        until_date="2026-08-13",
                        now=datetime(2026, 8, 12, 20, 0, tzinfo=UTC),
                    )
            finally:
                store.close()

    def test_arxiv_oai_window_rejects_a_future_checkpoint(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                store.set_sync_state(
                    "arxiv_oai",
                    None,
                    "checkpoint-token",
                    None,
                    datetime(2026, 8, 12, 18, 0, tzinfo=UTC),
                    completed_through=datetime(2026, 8, 11, tzinfo=UTC),
                    window_from="2026-08-12",
                    window_until="2026-08-13",
                )

                with self.assertRaisesRegex(ValueError, "2026-08-13"):
                    _arxiv_oai_window(
                        store,
                        from_date=None,
                        until_date=None,
                        now=datetime(2026, 8, 12, 20, 0, tzinfo=UTC),
                    )
            finally:
                store.close()

    def test_checkpoint_does_not_overwrite_last_success_time(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                successful_at = datetime(2026, 8, 11, 20, 0, tzinfo=UTC)
                store.set_sync_state("arxiv_oai", None, None, "success.json", successful_at)
                _ensure_arxiv_oai_checkpoint(
                    store,
                    "2026-08-11",
                    "2026-08-12",
                    datetime(2026, 8, 12, 20, 0, tzinfo=UTC),
                )
                self.assertEqual(
                    store.get_sync_state("arxiv_oai")["last_success_at"],
                    successful_at.isoformat(),
                )
            finally:
                store.close()

    def test_arxiv_oai_checkpoint_is_written_before_the_first_page(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                started_at = datetime(2026, 8, 12, 20, 0, tzinfo=UTC)
                state = _ensure_arxiv_oai_checkpoint(
                    store,
                    "2026-07-31",
                    "2026-08-12",
                    started_at,
                )

                self.assertIsNotNone(state["cursor"])
                self.assertEqual(state["last_success_at"], None)
                self.assertEqual(state["window_from"], "2026-07-31")
                self.assertEqual(state["window_until"], "2026-08-12")
                self.assertEqual(state["completed_through"], None)
                self.assertEqual(
                    _arxiv_oai_window(
                        store,
                        from_date=None,
                        until_date=None,
                        now=started_at,
                    ),
                    ("2026-07-31", "2026-08-12"),
                )
            finally:
                store.close()


if __name__ == "__main__":
    unittest.main()
