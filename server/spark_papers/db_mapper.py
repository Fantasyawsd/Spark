from __future__ import annotations

import json
import sqlite3
from datetime import datetime
from typing import Any

from . import PAPER_SCHEMA_VERSION
from .models import FieldProvenance, PaperRecord, parse_datetime


def _load(value: str | None, fallback: Any) -> Any:
    return fallback if value is None else json.loads(value)


def _required_datetime(value: Any, field_name: str) -> datetime:
    parsed = parse_datetime(value)
    if parsed is None:
        raise ValueError(f"{field_name} must contain a valid datetime")
    return parsed


def _optional_text(value: Any) -> str | None:
    if value is None:
        return None
    normalized = str(value).strip()
    return normalized or None


def paper_from_row(row: sqlite3.Row, provenance_rows: list[sqlite3.Row]) -> PaperRecord:
    return PaperRecord(
        paper_id=row["paper_id"],
        title=row["title"],
        abstract=_optional_text(row["abstract"]),
        authors=tuple(_load(row["authors_json"], [])),
        published_at=_required_datetime(row["published_at"], "published_at"),
        updated_at=parse_datetime(row["updated_at"]),
        subjects=tuple(_load(row["subjects_json"], [])),
        external_ids=_load(row["external_ids_json"], {}),
        discovery_sources=tuple(_load(row["discovery_sources_json"], [])),
        signals=_load(row["signals_json"], {}),
        metadata=_load(row["metadata_json"], {}),
        admitted=bool(row["admitted"]),
        admission_reason=row["admission_reason"],
        withdrawn=bool(row["withdrawn"]),
        schema_version=row["schema_version"],
        provenance=tuple(
            FieldProvenance(
                field_name=item["field_name"],
                source=item["source"],
                fetched_at=_required_datetime(
                    item["fetched_at"],
                    "provenance.fetched_at",
                ),
                source_updated_at=parse_datetime(item["source_updated_at"]),
                evidence=_load(item["evidence_json"], {}),
            )
            for item in provenance_rows
        ),
    )


def paper_values(paper: PaperRecord, created_at: datetime, last_seen_at: datetime) -> tuple[Any, ...]:
    return (
        paper.paper_id,
        paper.title,
        paper.abstract,
        json.dumps(paper.authors, ensure_ascii=True, sort_keys=True, separators=(",", ":")),
        paper.published_at.isoformat(),
        paper.updated_at.isoformat() if paper.updated_at else None,
        json.dumps(paper.subjects, ensure_ascii=True, sort_keys=True, separators=(",", ":")),
        json.dumps(dict(paper.external_ids), ensure_ascii=True, sort_keys=True, separators=(",", ":")),
        json.dumps(paper.discovery_sources, ensure_ascii=True, sort_keys=True, separators=(",", ":")),
        json.dumps(paper.signals, ensure_ascii=True, sort_keys=True, separators=(",", ":")),
        json.dumps(paper.metadata, ensure_ascii=True, sort_keys=True, separators=(",", ":")),
        int(paper.admitted),
        paper.admission_reason,
        int(paper.withdrawn),
        created_at.isoformat(),
        last_seen_at.isoformat(),
        paper.schema_version or PAPER_SCHEMA_VERSION,
    )
