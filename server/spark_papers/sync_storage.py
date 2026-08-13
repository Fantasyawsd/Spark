from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from datetime import datetime
from typing import Iterator

from .models import parse_datetime


class SyncStorage:
    """Persists source snapshots, checkpoints, and completion watermarks."""

    def __init__(self, connection: sqlite3.Connection) -> None:
        self._connection = connection

    @contextmanager
    def _transaction(self) -> Iterator[sqlite3.Connection]:
        try:
            yield self._connection
            self._connection.commit()
        except Exception:
            self._connection.rollback()
            raise

    def record_snapshot(
        self,
        source: str,
        snapshot_key: str,
        *,
        status: str,
        fetched_at: datetime,
        etag: str | None = None,
        cursor: str | None = None,
        raw_path: str | None = None,
        record_count: int = 0,
        error: str | None = None,
    ) -> None:
        with self._transaction() as connection:
            connection.execute(
                """INSERT INTO snapshots
                   (source, snapshot_key, fetched_at, status, etag, cursor, raw_path, record_count, error)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(source, snapshot_key) DO UPDATE SET
                    fetched_at=excluded.fetched_at, status=excluded.status, etag=excluded.etag,
                    cursor=excluded.cursor, raw_path=excluded.raw_path,
                    record_count=excluded.record_count, error=excluded.error""",
                (
                    source,
                    snapshot_key,
                    fetched_at.isoformat(),
                    status,
                    etag,
                    cursor,
                    raw_path,
                    record_count,
                    error,
                ),
            )

    def set_state(
        self,
        source: str,
        etag: str | None,
        cursor: str | None,
        path: str | None,
        at: datetime,
        *,
        completed_through: datetime | None = None,
        window_from: str | None = None,
        window_until: str | None = None,
        mark_success: bool = True,
    ) -> None:
        with self._transaction() as connection:
            connection.execute(
                """INSERT INTO sync_state(
                       source, etag, cursor, last_success_at, last_snapshot_path,
                       completed_through, window_from, window_until
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(source) DO UPDATE SET etag=excluded.etag, cursor=excluded.cursor,
                   last_success_at=COALESCE(excluded.last_success_at, sync_state.last_success_at),
                   last_snapshot_path=excluded.last_snapshot_path,
                   completed_through=CASE
                       WHEN excluded.completed_through IS NULL THEN sync_state.completed_through
                       WHEN sync_state.completed_through IS NULL THEN excluded.completed_through
                       WHEN excluded.completed_through > sync_state.completed_through THEN excluded.completed_through
                       ELSE sync_state.completed_through
                   END,
                   window_from=COALESCE(excluded.window_from, sync_state.window_from),
                   window_until=COALESCE(excluded.window_until, sync_state.window_until)""",
                (
                    source,
                    etag,
                    cursor,
                    at.isoformat() if mark_success else None,
                    path,
                    completed_through.isoformat() if completed_through else None,
                    window_from,
                    window_until,
                ),
            )

    def get_state(self, source: str) -> dict[str, str | None]:
        row = self._connection.execute(
            "SELECT * FROM sync_state WHERE source = ?",
            (source,),
        ).fetchone()
        if not row:
            return {
                "etag": None,
                "cursor": None,
                "last_success_at": None,
                "last_snapshot_path": None,
                "completed_through": None,
                "window_from": None,
                "window_until": None,
            }
        return dict(row)

    def latest_source_update(self, source: str) -> datetime | None:
        row = self._connection.execute(
            "SELECT MAX(source_updated_at) AS latest FROM source_observations WHERE source = ?",
            (source,),
        ).fetchone()
        return parse_datetime(row["latest"]) if row and row["latest"] else None
