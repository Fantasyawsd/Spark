from __future__ import annotations

import json
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from spark_papers.storage import PaperStore
from tests.test_recommendation_snapshot import legacy_fixture, sample_batch


class RecommendationBatchStorageTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "papers.sqlite3"
        self.store = PaperStore(self.path)
        self.addCleanup(self.store.close)

    def row(self, batch_id):
        row = self.store._connection.execute(
            "SELECT * FROM recommendation_batches WHERE batch_id = ?", (batch_id,),
        ).fetchone()
        return dict(row)

    def test_domain_and_legacy_writes_have_identical_stored_fields(self):
        batch = sample_batch()
        self.store.save_recommendation_batch(batch)
        self.store.record_batch(
            "legacy", batch.generated_at, batch.score_version, batch.sampling_seed,
            {"stored-paper": legacy_fixture()}, ["stored-paper"],
        )
        actual = self.row(batch.batch_id)
        legacy = self.row("legacy")
        actual.pop("batch_id")
        legacy.pop("batch_id")
        self.assertEqual(actual, legacy)

    def test_repeated_domain_batch_is_idempotent(self):
        batch = sample_batch()
        self.store.save_recommendation_batch(batch)
        expected = self.row(batch.batch_id)
        self.store.save_recommendation_batch(batch)
        self.assertEqual(self.row(batch.batch_id), expected)
        count = self.store._connection.execute(
            "SELECT COUNT(*) FROM recommendation_batches",
        ).fetchone()[0]
        self.assertEqual(count, 1)

    def test_saved_batch_is_visible_to_a_reopened_store(self):
        batch = sample_batch()
        self.store.save_recommendation_batch(batch)
        reopened = PaperStore(self.path)
        self.addCleanup(reopened.close)
        row = reopened._connection.execute(
            "SELECT feature_snapshot_json FROM recommendation_batches WHERE batch_id = ?",
            (batch.batch_id,),
        ).fetchone()
        self.assertEqual(json.loads(row[0]), {"stored-paper": legacy_fixture()})

    def test_invalid_mapping_does_not_replace_a_valid_batch(self):
        batch = sample_batch()
        self.store.save_recommendation_batch(batch)
        expected = self.row(batch.batch_id)
        invalid = replace(batch.items[0], paper=replace(
            batch.items[0].paper, metadata={"unsupported": object()},
        ))
        with self.assertRaises(TypeError):
            self.store.save_recommendation_batch(replace(batch, items=(invalid,)))
        self.assertEqual(self.row(batch.batch_id), expected)


if __name__ == "__main__":
    unittest.main()
