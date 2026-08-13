from __future__ import annotations

import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from spark_papers.models import FieldProvenance, PaperRecord
from spark_papers.storage import PaperStore


class StorageProvenanceTest(unittest.TestCase):
    def test_list_papers_loads_provenance_in_one_batch_query(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PaperStore(Path(directory) / "papers.sqlite3")
            try:
                now = datetime(2026, 8, 13, tzinfo=timezone.utc)
                for index in range(3):
                    paper = PaperRecord(
                        paper_id=f"paper-{index}",
                        title=f"Paper {index}",
                        abstract="Abstract",
                        authors=("Ada Lovelace",),
                        published_at=now,
                        updated_at=None,
                        subjects=("cs.AI",),
                        external_ids={"arxiv_id": f"2608.{index:05d}"},
                        discovery_sources=("arxiv",),
                        admitted=True,
                        provenance=(
                            FieldProvenance(
                                field_name="title",
                                source="arxiv",
                                fetched_at=now,
                                evidence={},
                            ),
                        ),
                    )
                    store.ingest(
                        paper,
                        source="arxiv",
                        external_id=f"2608.{index:05d}",
                        raw_payload={"title": paper.title},
                        fetched_at=now,
                    )

                statements: list[str] = []
                store._connection.set_trace_callback(statements.append)
                items, _ = store.list_papers(limit=3)

                provenance_queries = [
                    statement
                    for statement in statements
                    if "FROM provenance" in statement
                ]
                self.assertEqual(len(provenance_queries), 1)
                self.assertEqual(len(items), 3)
                self.assertTrue(all(item.provenance for item in items))
            finally:
                store.close()


if __name__ == "__main__":
    unittest.main()
