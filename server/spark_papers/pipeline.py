from __future__ import annotations

import hashlib
import json
import os
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any

from .models import parse_datetime, utc_now
from .normalization import normalize_record
from .policy import AiAdmissionPolicy
from .sources import SourceAdapter, SourceError
from .ports import PipelineRepository


class SnapshotStore:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)

    def save(self, source: str, snapshot_key: str, payload: Any, fetched_at: datetime) -> str:
        encoded = json.dumps(payload, ensure_ascii=True, sort_keys=True, default=str, indent=2).encode("utf-8")
        digest = hashlib.sha256(encoded).hexdigest()[:16]
        safe_key = "".join(char if char.isalnum() or char in "._-" else "_" for char in snapshot_key)[:80] or "snapshot"
        directory = self.root / source
        directory.mkdir(parents=True, exist_ok=True)
        target = directory / f"{safe_key}-{fetched_at.strftime('%Y%m%dT%H%M%SZ')}-{digest}.json"
        fd, temporary = tempfile.mkstemp(prefix=".snapshot-", suffix=".tmp", dir=directory)
        try:
            with os.fdopen(fd, "wb") as handle:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        return str(target)


class SyncRunner:
    def __init__(self, store: PipelineRepository, snapshot_store: SnapshotStore, policy: AiAdmissionPolicy | None = None) -> None:
        self.store = store
        self.snapshot_store = snapshot_store
        self.policy = policy or AiAdmissionPolicy()

    def sync(self, adapter: SourceAdapter, *, refresh_indexes: bool = True) -> dict[str, Any]:
        state = self.store.get_sync_state(adapter.name)
        now = utc_now()
        try:
            result = adapter.fetch(etag=state.get("etag"), cursor=state.get("cursor"))
        except SourceError as error:
            key = f"failed-{now.strftime('%Y%m%dT%H%M%SZ')}"
            self.store.record_snapshot(adapter.name, key, status="failed", fetched_at=now, error=str(error))
            return {"source": adapter.name, "status": "failed", "error": str(error), "retained_snapshot": state.get("last_snapshot_path")}
        key = result.snapshot_key or result.cursor or now.strftime("%Y%m%d")
        if result.not_modified:
            self.store.record_snapshot(adapter.name, key, status="not_modified", fetched_at=result.fetched_at, etag=result.etag, cursor=result.cursor, raw_path=state.get("last_snapshot_path"))
            return {"source": adapter.name, "status": "not_modified", "records": 0, "snapshot": state.get("last_snapshot_path")}
        raw_path = self.snapshot_store.save(adapter.name, key, result.raw_payload, result.fetched_at)
        ingested = 0
        unmatched = 0
        rejected = 0
        enrichment_only = bool(
            getattr(adapter, "enrichment_only", False)
            or adapter.name in {"openalex", "semantic_scholar", "github"}
        )
        for record in result.records:
            try:
                paper, external_id = normalize_record(adapter.name, record, fetched_at=result.fetched_at, policy=self.policy)
                paper_id = self.store.ingest(
                    paper,
                    source=adapter.name,
                    external_id=external_id,
                    raw_payload=record,
                    fetched_at=result.fetched_at,
                    source_updated_at=paper.updated_at,
                    etag=result.etag,
                    allow_create=not enrichment_only,
                )
                if paper_id is None:
                    unmatched += 1
                else:
                    ingested += 1
            except (TypeError, ValueError, KeyError):
                rejected += 1
        self.store.record_snapshot(adapter.name, key, status="success", fetched_at=result.fetched_at, etag=result.etag, cursor=result.cursor, raw_path=raw_path, record_count=ingested)
        self.store.set_sync_state(adapter.name, result.etag, result.cursor, raw_path, result.fetched_at)
        if refresh_indexes:
            self.store.refresh_indexes(result.fetched_at)
        return {
            "source": adapter.name,
            "status": "success",
            "records": ingested,
            "unmatched": unmatched,
            "rejected": rejected,
            "snapshot": raw_path,
        }

    def sync_paginated(
        self,
        adapter: SourceAdapter,
        *,
        state_name: str,
        max_pages: int = 100,
        admitted_only: bool = False,
        refresh_indexes: bool = True,
        completion_watermark: datetime | None = None,
        window_key: str | None = None,
    ) -> dict[str, Any]:
        """Sync a resumable source page by page and refresh indexes once at the end."""
        max_pages = max(1, int(max_pages))
        state = self.store.get_sync_state(state_name)
        cursor = state.get("cursor")
        page_count = 0
        ingested = 0
        excluded = 0
        unmatched = 0
        rejected = 0
        withdrawn = 0
        missing_withdrawals = 0
        last_snapshot: str | None = state.get("last_snapshot_path")
        last_fetched_at = utc_now()

        while page_count < max_pages:
            try:
                result = adapter.fetch(etag=state.get("etag"), cursor=cursor)
            except SourceError as error:
                now = utc_now()
                self.store.record_snapshot(
                    state_name,
                    f"failed-{now.strftime('%Y%m%dT%H%M%SZ')}",
                    status="failed",
                    fetched_at=now,
                    cursor=cursor,
                    error=str(error),
                )
                return {
                    "source": adapter.name,
                    "state": state_name,
                    "status": "failed",
                    "pages": page_count,
                    "records": ingested,
                    "excluded": excluded,
                    "unmatched": unmatched,
                    "rejected": rejected,
                    "withdrawn": withdrawn,
                    "missing_withdrawals": missing_withdrawals,
                    "error": str(error),
                    "retained_snapshot": last_snapshot,
                    "cursor": cursor,
                }

            page_count += 1
            last_fetched_at = result.fetched_at
            snapshot_window = window_key or getattr(adapter, "from_date", None) or "window"
            snapshot_until = getattr(adapter, "until_date", None) or "open"
            snapshot_key = (
                f"{snapshot_window}-{snapshot_until}-page-{page_count:04d}-"
                f"{result.cursor or 'complete'}"
            )
            raw_path = self.snapshot_store.save(state_name, snapshot_key, result.raw_payload, result.fetched_at)
            last_snapshot = raw_path
            page_ingested = 0
            page_excluded = 0
            page_unmatched = 0
            page_rejected = 0
            page_withdrawn = 0
            page_missing_withdrawals = 0
            for record in result.records:
                try:
                    if record.get("withdrawn") is True:
                        external_id = str(record.get("arxiv_id") or record.get("external_id") or "").strip()
                        deleted_at = parse_datetime(record.get("deleted_at"))
                        if external_id and self.store.withdraw_by_external_id(
                            source=adapter.name,
                            external_id=external_id,
                            raw_payload=record,
                            fetched_at=result.fetched_at,
                            source_updated_at=deleted_at,
                        ):
                            withdrawn += 1
                            page_withdrawn += 1
                        else:
                            missing_withdrawals += 1
                            page_missing_withdrawals += 1
                        continue
                    paper, external_id = normalize_record(
                        adapter.name,
                        record,
                        fetched_at=result.fetched_at,
                        policy=self.policy,
                    )
                    if admitted_only and not paper.admitted:
                        excluded += 1
                        page_excluded += 1
                        continue
                    paper_id = self.store.ingest(
                        paper,
                        source=adapter.name,
                        external_id=external_id,
                        raw_payload=record,
                        fetched_at=result.fetched_at,
                        source_updated_at=paper.updated_at,
                        etag=result.etag,
                        allow_create=True,
                    )
                    if paper_id is None:
                        unmatched += 1
                        page_unmatched += 1
                    else:
                        ingested += 1
                        page_ingested += 1
                except (TypeError, ValueError, KeyError):
                    rejected += 1
                    page_rejected += 1

            if page_rejected:
                error = (
                    f"page rejected {page_rejected} record(s); cursor retained for idempotent replay"
                )
                self.store.record_snapshot(
                    state_name,
                    snapshot_key,
                    status="failed",
                    fetched_at=result.fetched_at,
                    etag=result.etag,
                    cursor=cursor,
                    raw_path=raw_path,
                    record_count=page_ingested,
                    error=error,
                )
                return {
                    "source": adapter.name,
                    "state": state_name,
                    "status": "failed",
                    "pages": page_count,
                    "records": ingested,
                    "excluded": excluded,
                    "unmatched": unmatched,
                    "rejected": rejected,
                    "withdrawn": withdrawn,
                    "missing_withdrawals": missing_withdrawals,
                    "error": error,
                    "snapshot": raw_path,
                    "retained_snapshot": state.get("last_snapshot_path"),
                    "cursor": cursor,
                }

            cursor = result.cursor
            self.store.record_snapshot(
                state_name,
                snapshot_key,
                status="success",
                fetched_at=result.fetched_at,
                etag=result.etag,
                cursor=cursor,
                raw_path=raw_path,
                record_count=page_ingested,
                error=(
                    f"excluded={page_excluded};unmatched={page_unmatched};rejected={page_rejected};"
                    f"withdrawn={page_withdrawn};missing_withdrawals={page_missing_withdrawals}"
                    if page_excluded or page_unmatched or page_rejected or page_withdrawn or page_missing_withdrawals
                    else None
                ),
            )
            completed_through = completion_watermark if cursor is None else None
            self.store.set_sync_state(
                state_name,
                result.etag,
                cursor,
                raw_path,
                result.fetched_at,
                completed_through=completed_through,
                window_from=getattr(adapter, "from_date", None),
                window_until=getattr(adapter, "until_date", None),
            )
            state = self.store.get_sync_state(state_name)
            if cursor is None:
                if refresh_indexes:
                    self.store.refresh_indexes(last_fetched_at)
                return {
                    "source": adapter.name,
                    "state": state_name,
                    "status": "success",
                    "pages": page_count,
                    "records": ingested,
                    "excluded": excluded,
                    "unmatched": unmatched,
                    "rejected": rejected,
                    "withdrawn": withdrawn,
                    "missing_withdrawals": missing_withdrawals,
                    "snapshot": last_snapshot,
                    "cursor": None,
                    "indexes_refreshed": refresh_indexes,
                }

        return {
            "source": adapter.name,
            "state": state_name,
            "status": "partial",
            "pages": page_count,
            "records": ingested,
            "excluded": excluded,
            "unmatched": unmatched,
            "rejected": rejected,
            "withdrawn": withdrawn,
            "missing_withdrawals": missing_withdrawals,
            "snapshot": last_snapshot,
            "cursor": cursor,
        }
