from __future__ import annotations

import hashlib
import json
import os
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any

from .models import utc_now
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

    def sync(self, adapter: SourceAdapter) -> dict[str, Any]:
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
        rejected = 0
        for record in result.records:
            try:
                paper, external_id = normalize_record(adapter.name, record, fetched_at=result.fetched_at, policy=self.policy)
                self.store.ingest(
                    paper,
                    source=adapter.name,
                    external_id=external_id,
                    raw_payload=record,
                    fetched_at=result.fetched_at,
                    source_updated_at=paper.updated_at,
                    etag=result.etag,
                )
                ingested += 1
            except (TypeError, ValueError, KeyError):
                rejected += 1
        self.store.record_snapshot(adapter.name, key, status="success", fetched_at=result.fetched_at, etag=result.etag, cursor=result.cursor, raw_path=raw_path, record_count=ingested)
        self.store.set_sync_state(adapter.name, result.etag, result.cursor, raw_path, result.fetched_at)
        self.store.refresh_indexes(result.fetched_at)
        return {"source": adapter.name, "status": "success", "records": ingested, "rejected": rejected, "snapshot": raw_path}
