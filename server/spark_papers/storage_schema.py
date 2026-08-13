from __future__ import annotations

import re
import sqlite3
from collections.abc import Callable
from datetime import datetime
from pathlib import Path


_MIGRATION_PATTERN = re.compile(r"^(?P<version>\d{3})_[a-z0-9_]+\.sql$")


class StorageSchemaManager:
    """Creates the SQLite schema and applies ordered database migrations."""

    def __init__(
        self,
        connection: sqlite3.Connection,
        *,
        migrations_root: Path | None = None,
    ) -> None:
        self._connection = connection
        self._migrations_root = migrations_root or (
            Path(__file__).parent / "database" / "migrations"
        )

    def initialize(
        self,
        *,
        paper_schema_version: str,
        timestamp_factory: Callable[[], datetime],
    ) -> None:
        self.validate_database_version()
        self.create_schema(
            paper_schema_version=paper_schema_version,
            timestamp_factory=timestamp_factory,
        )
        self.apply_migrations()

    def create_schema(
        self,
        *,
        paper_schema_version: str,
        timestamp_factory: Callable[[], datetime],
    ) -> None:
        self._connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS papers (
                paper_id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                abstract TEXT,
                authors_json TEXT NOT NULL,
                published_at TEXT NOT NULL,
                updated_at TEXT,
                subjects_json TEXT NOT NULL,
                external_ids_json TEXT NOT NULL,
                discovery_sources_json TEXT NOT NULL,
                signals_json TEXT NOT NULL,
                metadata_json TEXT NOT NULL,
                admitted INTEGER NOT NULL,
                admission_reason TEXT NOT NULL,
                withdrawn INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                last_seen_at TEXT NOT NULL,
                schema_version TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_papers_published ON papers (published_at DESC, paper_id DESC);
            CREATE INDEX IF NOT EXISTS idx_papers_admitted ON papers (admitted, withdrawn, published_at DESC);

            CREATE TABLE IF NOT EXISTS paper_external_ids (
                id_type TEXT NOT NULL,
                id_value TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                PRIMARY KEY (id_type, id_value)
            );
            CREATE INDEX IF NOT EXISTS idx_external_ids_paper ON paper_external_ids (paper_id);

            CREATE TABLE IF NOT EXISTS source_observations (
                source TEXT NOT NULL,
                external_id TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                payload_json TEXT NOT NULL,
                source_updated_at TEXT,
                fetched_at TEXT NOT NULL,
                etag TEXT,
                PRIMARY KEY (source, external_id)
            );
            CREATE INDEX IF NOT EXISTS idx_observations_paper ON source_observations (paper_id);
            CREATE INDEX IF NOT EXISTS idx_observations_source_paper_fetched
                ON source_observations (source, paper_id, fetched_at);

            CREATE TABLE IF NOT EXISTS github_repository_links (
                paper_id TEXT PRIMARY KEY REFERENCES papers(paper_id),
                arxiv_id TEXT NOT NULL,
                github_url TEXT NOT NULL,
                discovered_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_github_links_arxiv
                ON github_repository_links (arxiv_id);

            CREATE TABLE IF NOT EXISTS provenance (
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                field_name TEXT NOT NULL,
                source TEXT NOT NULL,
                fetched_at TEXT NOT NULL,
                source_updated_at TEXT,
                evidence_json TEXT NOT NULL,
                PRIMARY KEY (paper_id, field_name, source)
            );

            CREATE TABLE IF NOT EXISTS snapshots (
                source TEXT NOT NULL,
                snapshot_key TEXT NOT NULL,
                fetched_at TEXT NOT NULL,
                status TEXT NOT NULL,
                etag TEXT,
                cursor TEXT,
                raw_path TEXT,
                record_count INTEGER NOT NULL DEFAULT 0,
                error TEXT,
                PRIMARY KEY (source, snapshot_key)
            );

            CREATE TABLE IF NOT EXISTS sync_state (
                source TEXT PRIMARY KEY,
                etag TEXT,
                cursor TEXT,
                last_success_at TEXT,
                last_snapshot_path TEXT
            );

            CREATE TABLE IF NOT EXISTS match_queue (
                queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
                source TEXT NOT NULL,
                external_id TEXT NOT NULL,
                candidate_paper_id TEXT,
                confidence REAL NOT NULL,
                reason TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                resolved_at TEXT
            );

            CREATE TABLE IF NOT EXISTS recommendation_batches (
                batch_id TEXT PRIMARY KEY,
                generated_at TEXT NOT NULL,
                score_version TEXT NOT NULL,
                sampling_seed INTEGER NOT NULL,
                feature_snapshot_json TEXT NOT NULL,
                selected_paper_ids_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS latest_index (
                paper_id TEXT PRIMARY KEY REFERENCES papers(paper_id),
                published_at TEXT NOT NULL,
                generated_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_latest_index_order ON latest_index (published_at DESC, paper_id DESC);

            CREATE TABLE IF NOT EXISTS channel_index (
                channel_key TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                sort_key TEXT NOT NULL,
                generated_at TEXT NOT NULL,
                PRIMARY KEY (channel_key, paper_id)
            );
            CREATE INDEX IF NOT EXISTS idx_channel_index_order ON channel_index (channel_key, sort_key DESC, paper_id DESC);

            CREATE TABLE IF NOT EXISTS candidate_index (
                pool TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                generated_at TEXT NOT NULL,
                sort_key REAL NOT NULL DEFAULT 0,
                published_at TEXT,
                PRIMARY KEY (pool, paper_id)
            );

            CREATE TABLE IF NOT EXISTS author_index (
                author_key TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                published_at TEXT NOT NULL,
                PRIMARY KEY (author_key, paper_id)
            );
            CREATE INDEX IF NOT EXISTS idx_author_index_order
                ON author_index(author_key, published_at DESC, paper_id DESC);

            CREATE TABLE IF NOT EXISTS venue_index (
                venue_key TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                published_at TEXT NOT NULL,
                PRIMARY KEY (venue_key, paper_id)
            );
            CREATE INDEX IF NOT EXISTS idx_venue_index_order
                ON venue_index(venue_key, published_at DESC, paper_id DESC);

            CREATE TABLE IF NOT EXISTS schema_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS dataset_imports (
                dataset_key TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                source_path TEXT NOT NULL,
                source_size INTEGER NOT NULL,
                source_mtime_ns INTEGER NOT NULL,
                byte_offset INTEGER NOT NULL DEFAULT 0,
                line_number INTEGER NOT NULL DEFAULT 0,
                processed_count INTEGER NOT NULL DEFAULT 0,
                imported_count INTEGER NOT NULL DEFAULT 0,
                duplicate_count INTEGER NOT NULL DEFAULT 0,
                rejected_count INTEGER NOT NULL DEFAULT 0,
                unmatched_count INTEGER NOT NULL DEFAULT 0,
                status TEXT NOT NULL,
                started_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                completed_at TEXT,
                error TEXT
            );

            CREATE TABLE IF NOT EXISTS dataset_rejections (
                dataset_key TEXT NOT NULL REFERENCES dataset_imports(dataset_key),
                line_number INTEGER NOT NULL,
                byte_offset INTEGER NOT NULL,
                error TEXT NOT NULL,
                payload_excerpt TEXT,
                created_at TEXT NOT NULL,
                PRIMARY KEY (dataset_key, line_number)
            );
            """
        )
        columns = {
            row["name"]
            for row in self._connection.execute("PRAGMA table_info(dataset_imports)")
        }
        if "run_token" not in columns:
            self._connection.execute(
                "ALTER TABLE dataset_imports ADD COLUMN run_token TEXT"
            )
        if "lease_expires_at" not in columns:
            self._connection.execute(
                "ALTER TABLE dataset_imports ADD COLUMN lease_expires_at TEXT"
            )
        candidate_columns = {
            row["name"]
            for row in self._connection.execute("PRAGMA table_info(candidate_index)")
        }
        if "sort_key" not in candidate_columns:
            self._connection.execute(
                "ALTER TABLE candidate_index ADD COLUMN sort_key REAL NOT NULL DEFAULT 0"
            )
        if "published_at" not in candidate_columns:
            self._connection.execute(
                "ALTER TABLE candidate_index ADD COLUMN published_at TEXT"
            )
        self._connection.execute(
            """CREATE INDEX IF NOT EXISTS idx_candidate_index_order
               ON candidate_index(pool, sort_key DESC, published_at DESC, paper_id DESC)"""
        )
        identity_marker = self._connection.execute(
            "SELECT 1 FROM schema_meta WHERE key = 'external_identity_index_v1'"
        ).fetchone()
        if identity_marker is None:
            self._connection.execute(
                """INSERT OR IGNORE INTO paper_external_ids(id_type, id_value, paper_id)
                   SELECT ids.key, CAST(ids.value AS TEXT), papers.paper_id
                   FROM papers, json_each(papers.external_ids_json) AS ids
                   WHERE ids.value IS NOT NULL AND CAST(ids.value AS TEXT) != ''"""
            )
            self._connection.execute(
                "INSERT INTO schema_meta(key, value, updated_at) VALUES ('external_identity_index_v1', 'complete', ?)",
                (timestamp_factory().isoformat(),),
            )
        self._connection.execute(
            "INSERT OR IGNORE INTO schema_meta(key, value, updated_at) VALUES ('paper_schema', ?, ?)",
            (paper_schema_version, timestamp_factory().isoformat()),
        )
        discovery_marker = self._connection.execute(
            "SELECT 1 FROM schema_meta WHERE key = 'discovery_sources_v2'"
        ).fetchone()
        if discovery_marker is None:
            self._connection.execute(
                """UPDATE papers
                   SET discovery_sources_json = COALESCE(
                       (
                           SELECT json_group_array(value)
                           FROM json_each(papers.discovery_sources_json)
                           WHERE value IN ('arxiv', 'huggingface')
                       ),
                       '[]'
                   )
                   WHERE EXISTS (
                       SELECT 1 FROM json_each(papers.discovery_sources_json)
                       WHERE value NOT IN ('arxiv', 'huggingface')
                   )"""
            )
            self._connection.execute(
                "INSERT INTO schema_meta(key, value, updated_at) VALUES ('discovery_sources_v2', 'complete', ?)",
                (timestamp_factory().isoformat(),),
            )
        self._connection.commit()

    def migration_files(self) -> list[tuple[int, Path]]:
        migrations: list[tuple[int, Path]] = []
        for path in sorted(self._migrations_root.glob("*.sql")):
            match = _MIGRATION_PATTERN.fullmatch(path.name)
            if match is None:
                raise RuntimeError(
                    f"invalid database migration filename: {path.name}"
                )
            migrations.append((int(match.group("version")), path))
        expected = list(range(1, len(migrations) + 1))
        actual = [version for version, _ in migrations]
        if actual != expected:
            raise RuntimeError(f"database migrations must be consecutive: {actual}")
        return migrations

    def validate_database_version(self) -> None:
        migrations = self.migration_files()
        latest = migrations[-1][0] if migrations else 0
        current = int(self._connection.execute("PRAGMA user_version").fetchone()[0])
        if current > latest:
            raise RuntimeError(
                f"database version {current} is newer than supported version {latest}"
            )

    def apply_migrations(self) -> None:
        current = int(self._connection.execute("PRAGMA user_version").fetchone()[0])
        for version, path in self.migration_files():
            if version <= current:
                continue
            script = path.read_text(encoding="utf-8")
            try:
                self._connection.executescript(
                    "BEGIN IMMEDIATE;\n"
                    + script
                    + f"\nPRAGMA user_version = {version};\nCOMMIT;"
                )
            except sqlite3.DatabaseError as error:
                if self._connection.in_transaction:
                    self._connection.rollback()
                raise RuntimeError(
                    f"database migration {path.name} failed: {error}"
                ) from error
            current = version
