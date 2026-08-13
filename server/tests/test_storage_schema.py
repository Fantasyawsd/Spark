from __future__ import annotations

import sqlite3
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from spark_papers.storage_schema import StorageSchemaManager


UTC = timezone.utc


class StorageSchemaManagerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.connection = sqlite3.connect(":memory:")
        self.connection.row_factory = sqlite3.Row

    def tearDown(self) -> None:
        self.connection.close()

    def test_initialize_creates_schema_and_compatibility_markers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            at = datetime(2026, 8, 14, 8, 30, tzinfo=UTC)
            StorageSchemaManager(
                self.connection,
                migrations_root=Path(directory),
            ).initialize(
                paper_schema_version="paper.v1",
                timestamp_factory=lambda: at,
            )

        tables = {
            row["name"]
            for row in self.connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        dataset_columns = {
            row["name"]
            for row in self.connection.execute("PRAGMA table_info(dataset_imports)")
        }
        markers = {
            row["key"]: (row["value"], row["updated_at"])
            for row in self.connection.execute(
                "SELECT key, value, updated_at FROM schema_meta"
            )
        }

        self.assertTrue(
            {
                "papers",
                "paper_external_ids",
                "source_observations",
                "dataset_imports",
                "schema_meta",
            }.issubset(tables)
        )
        self.assertTrue(
            {"run_token", "lease_expires_at"}.issubset(dataset_columns)
        )
        self.assertEqual(markers["paper_schema"], ("paper.v1", at.isoformat()))
        self.assertEqual(
            markers["external_identity_index_v1"],
            ("complete", at.isoformat()),
        )
        self.assertEqual(
            markers["discovery_sources_v2"],
            ("complete", at.isoformat()),
        )

    def test_migrations_are_applied_in_version_order_only_once(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "001_create_events.sql").write_text(
                "CREATE TABLE events(value TEXT NOT NULL);\n"
                "INSERT INTO events(value) VALUES ('one');\n",
                encoding="utf-8",
            )
            (root / "002_append_event.sql").write_text(
                "INSERT INTO events(value) VALUES ('two');\n",
                encoding="utf-8",
            )
            manager = StorageSchemaManager(
                self.connection,
                migrations_root=root,
            )

            manager.apply_migrations()
            manager.apply_migrations()

        self.assertEqual(
            [
                row["value"]
                for row in self.connection.execute("SELECT value FROM events")
            ],
            ["one", "two"],
        )
        self.assertEqual(
            self.connection.execute("PRAGMA user_version").fetchone()[0],
            2,
        )

    def test_invalid_migration_filename_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "migration.sql").write_text("SELECT 1;", encoding="utf-8")

            with self.assertRaisesRegex(
                RuntimeError,
                "invalid database migration filename: migration.sql",
            ):
                StorageSchemaManager(
                    self.connection,
                    migrations_root=root,
                ).migration_files()

    def test_nonconsecutive_migration_versions_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "002_second.sql").write_text("SELECT 1;", encoding="utf-8")

            with self.assertRaisesRegex(
                RuntimeError,
                r"database migrations must be consecutive: \[2\]",
            ):
                StorageSchemaManager(
                    self.connection,
                    migrations_root=root,
                ).migration_files()

    def test_future_database_version_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "001_first.sql").write_text("SELECT 1;", encoding="utf-8")
            self.connection.execute("PRAGMA user_version = 2")

            with self.assertRaisesRegex(
                RuntimeError,
                "database version 2 is newer than supported version 1",
            ):
                StorageSchemaManager(
                    self.connection,
                    migrations_root=root,
                ).validate_database_version()

    def test_failed_migration_rolls_back_its_changes_and_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "001_first.sql").write_text(
                "CREATE TABLE stable(value TEXT NOT NULL);\n",
                encoding="utf-8",
            )
            (root / "002_broken.sql").write_text(
                "CREATE TABLE transient(value TEXT NOT NULL);\n"
                "INSERT INTO transient(value) VALUES ('before failure');\n"
                "THIS IS NOT SQL;\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(
                RuntimeError,
                "database migration 002_broken.sql failed",
            ):
                StorageSchemaManager(
                    self.connection,
                    migrations_root=root,
                ).apply_migrations()

        tables = {
            row["name"]
            for row in self.connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        self.assertIn("stable", tables)
        self.assertNotIn("transient", tables)
        self.assertEqual(
            self.connection.execute("PRAGMA user_version").fetchone()[0],
            1,
        )


if __name__ == "__main__":
    unittest.main()
