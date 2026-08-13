from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta
from typing import Any, Callable, Iterator, Mapping

from .database_values import encode_json, load_json, merge_nested_json
from .db_mapper import paper_values
from .models import parse_datetime


class DatasetStorage:
    """Persists dataset import leases, checkpoints, batches, and rejections."""

    def __init__(
        self,
        connection: sqlite3.Connection,
        *,
        timestamp_factory: Callable[[], datetime],
    ) -> None:
        self._connection = connection
        self._timestamp_factory = timestamp_factory

    @contextmanager
    def _transaction(self) -> Iterator[sqlite3.Connection]:
        try:
            yield self._connection
            self._connection.commit()
        except Exception:
            self._connection.rollback()
            raise

    def start_import(
        self,
        *,
        dataset_key: str,
        source: str,
        source_path: str,
        source_size: int,
        source_mtime_ns: int,
        started_at: datetime,
        run_token: str,
        lease_seconds: int = 120,
    ) -> dict[str, Any]:
        existing = self.get_import(dataset_key)
        lease_expires_at = started_at + timedelta(seconds=max(30, lease_seconds))
        if existing is not None:
            unchanged = (
                existing["source_path"] == source_path
                and int(existing["source_size"]) == source_size
                and int(existing["source_mtime_ns"]) == source_mtime_ns
            )
            if not unchanged:
                raise ValueError(
                    f"dataset source changed after checkpoint: {dataset_key}"
                )
            if existing["status"] == "completed":
                return existing
            active_lease = parse_datetime(existing.get("lease_expires_at"))
            if (
                existing.get("run_token")
                and existing["run_token"] != run_token
                and active_lease is not None
                and active_lease > started_at
            ):
                raise RuntimeError(f"dataset import already running: {dataset_key}")
            self._connection.execute(
                """UPDATE dataset_imports SET status = 'running', error = NULL,
                   run_token = ?, lease_expires_at = ?, updated_at = ? WHERE dataset_key = ?""",
                (
                    run_token,
                    lease_expires_at.isoformat(),
                    started_at.isoformat(),
                    dataset_key,
                ),
            )
            self._connection.commit()
            return self.get_import(dataset_key) or existing
        self._connection.execute(
            """INSERT INTO dataset_imports(
                   dataset_key, source, source_path, source_size, source_mtime_ns,
                   status, started_at, updated_at, run_token, lease_expires_at
               ) VALUES (?, ?, ?, ?, ?, 'running', ?, ?, ?, ?)""",
            (
                dataset_key,
                source,
                source_path,
                source_size,
                source_mtime_ns,
                started_at.isoformat(),
                started_at.isoformat(),
                run_token,
                lease_expires_at.isoformat(),
            ),
        )
        self._connection.commit()
        return self.get_import(dataset_key) or {}

    def get_import(self, dataset_key: str) -> dict[str, Any] | None:
        row = self._connection.execute(
            "SELECT * FROM dataset_imports WHERE dataset_key = ?", (dataset_key,)
        ).fetchone()
        return dict(row) if row else None

    def list_imports(self, prefix: str = "") -> list[dict[str, Any]]:
        if prefix:
            rows = self._connection.execute(
                "SELECT * FROM dataset_imports WHERE dataset_key LIKE ? ORDER BY dataset_key",
                (prefix + "%",),
            ).fetchall()
        else:
            rows = self._connection.execute(
                "SELECT * FROM dataset_imports ORDER BY dataset_key"
            ).fetchall()
        return [dict(row) for row in rows]

    def apply_paper_batch(
        self,
        *,
        dataset_key: str,
        records: list[Mapping[str, Any]],
        rejections: list[Mapping[str, Any]],
        byte_offset: int,
        line_number: int,
        fetched_at: datetime,
        run_token: str,
        lease_seconds: int = 120,
    ) -> dict[str, int]:
        paper_ids = [str(item["paper"].paper_id) for item in records]
        existing_ids: set[str] = set()
        for start in range(0, len(paper_ids), 500):
            chunk = paper_ids[start : start + 500]
            if not chunk:
                continue
            placeholders = ",".join("?" for _ in chunk)
            rows = self._connection.execute(
                f"SELECT paper_id FROM papers WHERE paper_id IN ({placeholders})",
                chunk,
            ).fetchall()
            existing_ids.update(row["paper_id"] for row in rows)
        unique_ids = set(paper_ids)
        imported = len(unique_ids - existing_ids)
        duplicates = len(records) - imported
        at = fetched_at.isoformat()
        with self._transaction() as connection:
            connection.executemany(
                """INSERT INTO papers(
                       paper_id, title, abstract, authors_json, published_at, updated_at,
                       subjects_json, external_ids_json, discovery_sources_json, signals_json,
                       metadata_json, admitted, admission_reason, withdrawn, created_at,
                       last_seen_at, schema_version
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(paper_id) DO UPDATE SET
                       title=excluded.title, abstract=excluded.abstract,
                       authors_json=excluded.authors_json, published_at=excluded.published_at,
                       updated_at=excluded.updated_at, subjects_json=excluded.subjects_json,
                       external_ids_json=json_patch(papers.external_ids_json, excluded.external_ids_json),
                       signals_json=json_patch(papers.signals_json, excluded.signals_json),
                       metadata_json=json_patch(papers.metadata_json, excluded.metadata_json),
                       admitted=excluded.admitted, admission_reason=excluded.admission_reason,
                       withdrawn=excluded.withdrawn, last_seen_at=excluded.last_seen_at,
                       schema_version=excluded.schema_version""",
                (paper_values(item["paper"], fetched_at, fetched_at) for item in records),
            )
            identity_rows = [
                (key, value, item["paper"].paper_id)
                for item in records
                for key, value in item["paper"].external_ids.items()
            ]
            connection.executemany(
                """INSERT INTO paper_external_ids(id_type, id_value, paper_id)
                   VALUES (?, ?, ?)
                   ON CONFLICT(id_type, id_value) DO UPDATE SET paper_id=excluded.paper_id""",
                identity_rows,
            )
            connection.executemany(
                """INSERT INTO source_observations(
                       source, external_id, paper_id, payload_json, source_updated_at, fetched_at, etag
                   ) VALUES (?, ?, ?, ?, ?, ?, NULL)
                   ON CONFLICT(source, external_id) DO UPDATE SET
                       paper_id=excluded.paper_id, payload_json=excluded.payload_json,
                       source_updated_at=excluded.source_updated_at, fetched_at=excluded.fetched_at""",
                (
                    (
                        item["source"],
                        item["external_id"],
                        item["paper"].paper_id,
                        encode_json(item["raw_payload"]),
                        item["source_updated_at"].isoformat()
                        if item.get("source_updated_at")
                        else None,
                        at,
                    )
                    for item in records
                ),
            )
            provenance_rows = [
                (
                    item["paper"].paper_id,
                    field_name,
                    item["source"],
                    at,
                    item["source_updated_at"].isoformat()
                    if item.get("source_updated_at")
                    else None,
                    encode_json(evidence),
                )
                for item in records
                for field_name, evidence in item["provenance"].items()
            ]
            connection.executemany(
                """INSERT INTO provenance(
                       paper_id, field_name, source, fetched_at, source_updated_at, evidence_json
                   ) VALUES (?, ?, ?, ?, ?, ?)
                   ON CONFLICT(paper_id, field_name, source) DO UPDATE SET
                       fetched_at=excluded.fetched_at,
                       source_updated_at=excluded.source_updated_at,
                       evidence_json=excluded.evidence_json""",
                provenance_rows,
            )
            self._insert_rejections(connection, dataset_key, rejections, fetched_at)
            updated = connection.execute(
                """UPDATE dataset_imports SET
                       byte_offset = ?, line_number = ?,
                       processed_count = processed_count + ?,
                       imported_count = imported_count + ?,
                       duplicate_count = duplicate_count + ?,
                       rejected_count = rejected_count + ?,
                       status = 'running', updated_at = ?, error = NULL,
                       lease_expires_at = ?
                   WHERE dataset_key = ? AND run_token = ?""",
                (
                    byte_offset,
                    line_number,
                    len(records) + len(rejections),
                    imported,
                    duplicates,
                    len(rejections),
                    at,
                    (
                        fetched_at + timedelta(seconds=max(30, lease_seconds))
                    ).isoformat(),
                    dataset_key,
                    run_token,
                ),
            )
            if updated.rowcount != 1:
                raise RuntimeError(f"dataset import lease lost: {dataset_key}")
        return {
            "imported": imported,
            "duplicates": duplicates,
            "rejected": len(rejections),
        }

    def apply_enrichment_batch(
        self,
        *,
        dataset_key: str,
        records: list[Mapping[str, Any]],
        rejections: list[Mapping[str, Any]],
        byte_offset: int,
        line_number: int,
        fetched_at: datetime,
        run_token: str,
        lease_seconds: int = 120,
    ) -> dict[str, int]:
        lookup_values = tuple(
            dict.fromkeys(str(item["lookup_value"]) for item in records)
        )
        identities: dict[str, str] = {}
        for start in range(0, len(lookup_values), 500):
            chunk = lookup_values[start : start + 500]
            if not chunk:
                continue
            placeholders = ",".join("?" for _ in chunk)
            rows = self._connection.execute(
                f"SELECT id_value, paper_id FROM paper_external_ids "
                f"WHERE id_type = 'arxiv_id' AND id_value IN ({placeholders})",
                chunk,
            ).fetchall()
            identities.update({row["id_value"]: row["paper_id"] for row in rows})
        matched_records = [
            (item, identities.get(str(item["lookup_value"]))) for item in records
        ]
        matched_records = [
            (item, paper_id)
            for item, paper_id in matched_records
            if paper_id is not None
        ]
        paper_ids = tuple(
            dict.fromkeys(str(paper_id) for _, paper_id in matched_records)
        )
        current_rows: dict[str, sqlite3.Row] = {}
        for start in range(0, len(paper_ids), 500):
            chunk = paper_ids[start : start + 500]
            if not chunk:
                continue
            placeholders = ",".join("?" for _ in chunk)
            rows = self._connection.execute(
                f"SELECT paper_id, external_ids_json, signals_json, metadata_json FROM papers "
                f"WHERE paper_id IN ({placeholders})",
                chunk,
            ).fetchall()
            current_rows.update({row["paper_id"]: row for row in rows})
        at = fetched_at.isoformat()
        updates: list[tuple[str, str, str, str, str]] = []
        identity_rows: list[tuple[str, str, str]] = []
        observation_rows: list[tuple[Any, ...]] = []
        provenance_rows: list[tuple[Any, ...]] = []
        for item, paper_id in matched_records:
            current = current_rows[str(paper_id)]
            external_ids = merge_nested_json(
                load_json(current["external_ids_json"], {}),
                item.get("external_ids") or {},
            )
            signals = merge_nested_json(
                load_json(current["signals_json"], {}),
                item.get("signals") or {},
            )
            metadata = merge_nested_json(
                load_json(current["metadata_json"], {}),
                item.get("metadata") or {},
            )
            updates.append(
                (
                    encode_json(external_ids),
                    encode_json(signals),
                    encode_json(metadata),
                    at,
                    str(paper_id),
                )
            )
            identity_rows.extend(
                (key, value, str(paper_id))
                for key, value in (item.get("external_ids") or {}).items()
            )
            observation_rows.append(
                (
                    item["source"],
                    item["external_id"],
                    str(paper_id),
                    encode_json(item["raw_payload"]),
                    at,
                )
            )
            provenance_rows.extend(
                (
                    str(paper_id),
                    field_name,
                    item["source"],
                    at,
                    encode_json(evidence),
                )
                for field_name, evidence in item["provenance"].items()
            )
        unmatched = len(records) - len(matched_records)
        with self._transaction() as connection:
            connection.executemany(
                """UPDATE papers SET external_ids_json = ?, signals_json = ?, metadata_json = ?,
                   last_seen_at = ? WHERE paper_id = ?""",
                updates,
            )
            connection.executemany(
                """INSERT INTO paper_external_ids(id_type, id_value, paper_id)
                   VALUES (?, ?, ?)
                   ON CONFLICT(id_type, id_value) DO UPDATE SET paper_id=excluded.paper_id""",
                identity_rows,
            )
            connection.executemany(
                """INSERT INTO source_observations(
                       source, external_id, paper_id, payload_json, source_updated_at, fetched_at, etag
                   ) VALUES (?, ?, ?, ?, NULL, ?, NULL)
                   ON CONFLICT(source, external_id) DO UPDATE SET
                       paper_id=excluded.paper_id, payload_json=excluded.payload_json,
                       fetched_at=excluded.fetched_at""",
                observation_rows,
            )
            connection.executemany(
                """INSERT INTO provenance(
                       paper_id, field_name, source, fetched_at, source_updated_at, evidence_json
                   ) VALUES (?, ?, ?, ?, NULL, ?)
                   ON CONFLICT(paper_id, field_name, source) DO UPDATE SET
                       fetched_at=excluded.fetched_at, evidence_json=excluded.evidence_json""",
                provenance_rows,
            )
            self._insert_rejections(connection, dataset_key, rejections, fetched_at)
            updated = connection.execute(
                """UPDATE dataset_imports SET
                       byte_offset = ?, line_number = ?,
                       processed_count = processed_count + ?,
                       imported_count = imported_count + ?,
                       rejected_count = rejected_count + ?,
                       unmatched_count = unmatched_count + ?,
                       status = 'running', updated_at = ?, error = NULL,
                       lease_expires_at = ?
                   WHERE dataset_key = ? AND run_token = ?""",
                (
                    byte_offset,
                    line_number,
                    len(records) + len(rejections),
                    len(matched_records),
                    len(rejections),
                    unmatched,
                    at,
                    (
                        fetched_at + timedelta(seconds=max(30, lease_seconds))
                    ).isoformat(),
                    dataset_key,
                    run_token,
                ),
            )
            if updated.rowcount != 1:
                raise RuntimeError(f"dataset import lease lost: {dataset_key}")
        return {
            "matched": len(matched_records),
            "unmatched": unmatched,
            "rejected": len(rejections),
        }

    def _insert_rejections(
        self,
        connection: sqlite3.Connection,
        dataset_key: str,
        rejections: list[Mapping[str, Any]],
        created_at: datetime,
    ) -> None:
        connection.executemany(
            """INSERT OR REPLACE INTO dataset_rejections(
                   dataset_key, line_number, byte_offset, error, payload_excerpt, created_at
               ) VALUES (?, ?, ?, ?, ?, ?)""",
            (
                (
                    dataset_key,
                    int(item["line_number"]),
                    int(item["byte_offset"]),
                    str(item["error"]),
                    str(item.get("payload_excerpt") or "")[:1000],
                    created_at.isoformat(),
                )
                for item in rejections
            ),
        )

    def complete_import(
        self,
        dataset_key: str,
        completed_at: datetime,
        *,
        run_token: str,
    ) -> dict[str, Any]:
        updated = self._connection.execute(
            """UPDATE dataset_imports SET status = 'completed', completed_at = ?,
               updated_at = ?, error = NULL, run_token = NULL, lease_expires_at = NULL
               WHERE dataset_key = ? AND run_token = ?""",
            (
                completed_at.isoformat(),
                completed_at.isoformat(),
                dataset_key,
                run_token,
            ),
        )
        if updated.rowcount != 1:
            self._connection.rollback()
            raise RuntimeError(f"dataset import lease lost: {dataset_key}")
        self._connection.commit()
        return self.get_import(dataset_key) or {}

    def pause_import(
        self,
        dataset_key: str,
        paused_at: datetime,
        *,
        run_token: str,
    ) -> dict[str, Any]:
        updated = self._connection.execute(
            """UPDATE dataset_imports SET run_token = NULL, lease_expires_at = NULL,
               updated_at = ? WHERE dataset_key = ? AND run_token = ?""",
            (paused_at.isoformat(), dataset_key, run_token),
        )
        if updated.rowcount != 1:
            self._connection.rollback()
            raise RuntimeError(f"dataset import lease lost: {dataset_key}")
        self._connection.commit()
        return self.get_import(dataset_key) or {}

    def fail_import(
        self,
        dataset_key: str,
        error: str,
        failed_at: datetime,
        *,
        run_token: str,
    ) -> None:
        self._connection.execute(
            """UPDATE dataset_imports SET status = 'failed', error = ?, updated_at = ?,
               run_token = NULL, lease_expires_at = NULL
               WHERE dataset_key = ? AND run_token = ?""",
            (error, failed_at.isoformat(), dataset_key, run_token),
        )
        self._connection.commit()

    def reconcile_arxiv_import(
        self,
        dataset_key: str,
        source_path: str,
    ) -> dict[str, Any]:
        state = self.get_import(dataset_key)
        if state is None:
            raise ValueError(f"unknown dataset import: {dataset_key}")
        observations = int(
            self._connection.execute(
                """SELECT COUNT(*) FROM source_observations
                   WHERE source = 'arxiv'
                     AND json_extract(payload_json, '$.source_path') = ?""",
                (source_path,),
            ).fetchone()[0]
        )
        rejected = int(
            self._connection.execute(
                "SELECT COUNT(*) FROM dataset_rejections WHERE dataset_key = ?",
                (dataset_key,),
            ).fetchone()[0]
        )
        processed = int(state["line_number"])
        duplicates = max(processed - observations - rejected, 0)
        self._connection.execute(
            """UPDATE dataset_imports SET processed_count = ?, imported_count = ?,
               duplicate_count = ?, rejected_count = ?, updated_at = ?
               WHERE dataset_key = ?""",
            (
                processed,
                observations,
                duplicates,
                rejected,
                self._timestamp_factory().isoformat(),
                dataset_key,
            ),
        )
        self._connection.commit()
        return self.get_import(dataset_key) or {}
