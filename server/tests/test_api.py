from __future__ import annotations

import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch

from spark_papers.api import INTERNAL_ERROR_MESSAGE, PaperApiService, create_server
from spark_papers.diagnostics import DIAGNOSTIC_LOGGER_NAME
from spark_papers.pipeline import SnapshotStore, SyncRunner
from spark_papers.sources import StaticSource
from spark_papers.storage import PaperStore


class ApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.store = PaperStore(Path(self.directory.name) / "papers.sqlite3")
        records = tuple(
            {
                "arxiv_id": f"2401.{index:05d}",
                "title": f"AI Paper {index}",
                "abstract": "Abstract",
                "authors": [{"name": "Ada Lovelace"}],
                "published_at": f"2024-01-{index + 1:02d}T00:00:00Z",
                "subjects": ["cs.AI" if index % 2 == 0 else "cs.LG"],
                "signals": {"openalex": {"citation_count": index + 1}},
                "metadata": {"venue_name": "ICML", "venue_year": 2024, "track": "Long Paper"} if index == 0 else {},
            }
            for index in range(5)
        )
        SyncRunner(self.store, SnapshotStore(Path(self.directory.name) / "snapshots")).sync(StaticSource("arxiv", records))
        self.server = create_server(PaperApiService(self.store), port=0)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base_url = f"http://127.0.0.1:{self.server.server_address[1]}"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.store.close()
        self.directory.cleanup()

    def get(self, path: str) -> tuple[int, dict]:
        try:
            with urllib.request.urlopen(self.base_url + path, timeout=3) as response:
                return response.status, json.loads(response.read())
        except urllib.error.HTTPError as error:
            return error.code, json.loads(error.read())

    def test_latest_has_opaque_cursor_and_subject_filter(self) -> None:
        status, first = self.get("/api/v1/channels/latest?limit=2")
        self.assertEqual(status, 200)
        self.assertEqual(len(first["items"]), 2)
        self.assertTrue(first["next_cursor"])
        status, second = self.get("/api/v1/channels/latest?limit=2&cursor=" + first["next_cursor"])
        self.assertEqual(status, 200)
        self.assertTrue({item["paper_id"] for item in first["items"]}.isdisjoint(item["paper_id"] for item in second["items"]))
        status, subject = self.get("/api/v1/channels/subject/cs.AI?limit=10")
        self.assertEqual(status, 200)
        self.assertTrue(all("cs.AI" in item["subjects"] for item in subject["items"]))
        status, conference = self.get("/api/v1/channels/conference/ICML?year=2024&track=Long%20Paper")
        self.assertEqual(status, 200)
        self.assertEqual(len(conference["items"]), 1)

        status, following = self.get("/api/v1/channels/following?authors=Ada%20Lovelace&limit=2")
        self.assertEqual(status, 200)
        self.assertEqual(len(following["items"]), 2)
        self.assertTrue(following["next_cursor"])

    def test_recommended_and_detail_errors(self) -> None:
        status, payload = self.get("/api/v1/feed/recommended?limit=3&seed=7")
        self.assertEqual(status, 200)
        self.assertEqual(payload["score_version"], "score.v1")
        read_id = payload["items"][0]["paper_id"]
        status, filtered = self.get(f"/api/v1/feed/recommended?limit=3&seed=7&read_ids={read_id}")
        self.assertEqual(status, 200)
        self.assertNotIn(read_id, {item["paper_id"] for item in filtered["items"]})
        status, missing = self.get("/api/v1/papers/paper_missing")
        self.assertEqual(status, 404)
        self.assertEqual(missing["error"], "not_found")

    def test_invalid_query_is_rejected(self) -> None:
        with self.assertNoLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR"):
            status, payload = self.get("/api/v1/channels/subject/cs.AI?from=not-a-date")
        self.assertEqual(status, 400)
        self.assertEqual(payload["error"], "invalid_request")

    def test_internal_failure_is_logged_without_leaking_request_or_error(self) -> None:
        secret_error = RuntimeError(
            "token=server-secret prompt=private-paper-body query=private-query"
        )
        with (
            patch.object(self.store, "count", side_effect=secret_error),
            self.assertLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR") as logs,
        ):
            status, payload = self.get(
                "/api/v1/health?token=request-secret&query=private-query"
            )

        self.assertEqual(status, 500)
        self.assertEqual(
            payload,
            {"error": "internal_error", "message": INTERNAL_ERROR_MESSAGE},
        )
        output = "\n".join(logs.output)
        self.assertIn("operation=http.request", output)
        self.assertIn("type=RuntimeError", output)
        self.assertIn("api.py", output)
        for secret in (
            "server-secret",
            "private-paper-body",
            "private-query",
            "request-secret",
        ):
            self.assertNotIn(secret, output)

    def test_non_json_service_payload_uses_the_same_fixed_500_boundary(self) -> None:
        with (
            patch.object(self.store, "count", return_value=object()),
            self.assertLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR") as logs,
        ):
            status, payload = self.get("/api/v1/health")

        self.assertEqual(status, 500)
        self.assertEqual(
            payload,
            {"error": "internal_error", "message": INTERNAL_ERROR_MESSAGE},
        )
        self.assertEqual(len(logs.records), 1)
        self.assertIn("type=TypeError", logs.records[0].getMessage())
