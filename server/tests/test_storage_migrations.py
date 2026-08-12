from __future__ import annotations

import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

from spark_papers.storage import PaperStore


class StorageMigrationTest(unittest.TestCase):
    def test_legacy_database_upgrades_once_and_preserves_oai_watermark(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "papers.sqlite3"
            connection = sqlite3.connect(path)
            connection.executescript(
                """
                CREATE TABLE sync_state (
                    source TEXT PRIMARY KEY,
                    etag TEXT,
                    cursor TEXT,
                    last_success_at TEXT,
                    last_snapshot_path TEXT
                );
                INSERT INTO sync_state(
                    source, etag, cursor, last_success_at, last_snapshot_path
                ) VALUES (
                    'arxiv_oai', NULL, NULL, '2026-08-12T00:00:00+00:00', 'snapshot.json'
                );
                """
            )
            connection.close()

            migrated = PaperStore(path)
            try:
                state = migrated.get_sync_state("arxiv_oai")
                columns = {
                    row["name"]
                    for row in migrated._connection.execute("PRAGMA table_info(sync_state)")
                }
                version = migrated._connection.execute("PRAGMA user_version").fetchone()[0]
                self.assertEqual(version, 1)
                self.assertTrue(
                    {"completed_through", "window_from", "window_until"}.issubset(columns)
                )
                self.assertEqual(
                    state["completed_through"],
                    "2026-08-12T00:00:00+00:00",
                )
            finally:
                migrated.close()

            reopened = PaperStore(path)
            try:
                self.assertEqual(
                    reopened._connection.execute("PRAGMA user_version").fetchone()[0],
                    1,
                )
            finally:
                reopened.close()

    def test_future_database_version_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "papers.sqlite3"
            connection = sqlite3.connect(path)
            connection.execute("PRAGMA user_version = 2")
            connection.close()

            with self.assertRaisesRegex(RuntimeError, "newer than supported version 1"):
                PaperStore(path)

    def test_built_wheel_contains_and_applies_migration(self) -> None:
        server_root = Path(__file__).parents[1]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            shutil.copytree(
                server_root,
                source,
                ignore=shutil.ignore_patterns(
                    "build",
                    "dist",
                    "*.egg-info",
                    "__pycache__",
                    "*.pyc",
                ),
            )
            wheel_directory = root / "wheel"
            install_directory = root / "installed"
            wheel_directory.mkdir()
            install_directory.mkdir()

            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "pip",
                    "wheel",
                    str(source),
                    "--no-deps",
                    "--no-build-isolation",
                    "--wheel-dir",
                    str(wheel_directory),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            wheel = next(wheel_directory.glob("*.whl"))
            with zipfile.ZipFile(wheel) as archive:
                self.assertIn(
                    "spark_papers/database/migrations/001_oai_sync_windows.sql",
                    archive.namelist(),
                )

            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "pip",
                    "install",
                    "--no-deps",
                    "--target",
                    str(install_directory),
                    str(wheel),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            code = """
import sqlite3
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from spark_papers.storage import PaperStore
path = Path(sys.argv[2])
connection = sqlite3.connect(path)
connection.execute(
    'CREATE TABLE sync_state ('
    'source TEXT PRIMARY KEY, etag TEXT, cursor TEXT, '
    'last_success_at TEXT, last_snapshot_path TEXT)'
)
connection.close()
store = PaperStore(path)
assert store._connection.execute('PRAGMA user_version').fetchone()[0] == 1
store.close()
"""
            subprocess.run(
                [
                    sys.executable,
                    "-I",
                    "-c",
                    code,
                    str(install_directory),
                    str(root / "legacy.sqlite3"),
                ],
                check=True,
                capture_output=True,
                text=True,
                cwd=root,
            )


if __name__ == "__main__":
    unittest.main()
