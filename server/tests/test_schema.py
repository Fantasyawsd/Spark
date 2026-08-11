from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from spark_papers.pipeline import SnapshotStore, SyncRunner
from spark_papers.dto import paper_to_api
from spark_papers.sources import StaticSource
from spark_papers.storage import PaperStore


class SchemaContractTest(unittest.TestCase):
    def test_paper_schema_is_versioned_and_matches_runtime_shape(self) -> None:
        schema_path = Path(__file__).parents[1] / "schema" / "paper.v1.json"
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        self.assertEqual(schema["properties"]["schema_version"]["const"], "paper.v1")
        with _StoreContext() as store, tempfile.TemporaryDirectory() as directory:
            SyncRunner(store, SnapshotStore(directory)).sync(
                StaticSource(
                    "arxiv",
                    ({"arxiv_id": "2401.12345", "title": "Schema Paper", "authors": ["Ada"], "published_at": "2024-01-01T00:00:00Z", "subjects": ["cs.AI"]},),
                )
            )
            paper = paper_to_api(store.all_candidates()[0])
        self.assertTrue(set(schema["required"]).issubset(paper))
        self.assertEqual(paper["schema_version"], "paper.v1")


class _StoreContext:
    def __enter__(self):
        self.store = PaperStore()
        return self.store

    def __exit__(self, exc_type, exc, traceback):
        self.store.close()
