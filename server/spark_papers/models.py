from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any, Mapping

from . import PAPER_SCHEMA_VERSION


def utc_now() -> datetime:
    return datetime.now(UTC).replace(microsecond=0)


def parse_datetime(value: Any) -> datetime | None:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        parsed = value
    else:
        text = str(value).strip()
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        try:
            parsed = datetime.fromisoformat(text)
        except ValueError:
            return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC).replace(microsecond=0)


@dataclass(frozen=True)
class FieldProvenance:
    field_name: str
    source: str
    fetched_at: datetime
    source_updated_at: datetime | None = None
    evidence: Mapping[str, Any] = field(default_factory=dict)

@dataclass(frozen=True)
class PaperRecord:
    paper_id: str
    title: str
    abstract: str | None
    authors: tuple[str, ...]
    published_at: datetime
    updated_at: datetime | None
    subjects: tuple[str, ...]
    external_ids: Mapping[str, str]
    discovery_sources: tuple[str, ...]
    signals: Mapping[str, Mapping[str, Any]] = field(default_factory=dict)
    metadata: Mapping[str, Any] = field(default_factory=dict)
    admitted: bool = False
    admission_reason: str = ""
    withdrawn: bool = False
    schema_version: str = PAPER_SCHEMA_VERSION
    provenance: tuple[FieldProvenance, ...] = ()

    def __post_init__(self) -> None:
        if not self.paper_id:
            raise ValueError("paper_id must not be empty")
        if not self.title.strip():
            raise ValueError("title must not be empty")
        if self.published_at.tzinfo is None:
            raise ValueError("published_at must be timezone-aware")



@dataclass(frozen=True)
class SourceObservation:
    source: str
    external_id: str
    record: Mapping[str, Any]
    fetched_at: datetime
    source_updated_at: datetime | None = None
    etag: str | None = None


@dataclass(frozen=True)
class FetchResult:
    source: str
    records: tuple[Mapping[str, Any], ...]
    raw_payload: Any
    fetched_at: datetime
    cursor: str | None = None
    etag: str | None = None
    snapshot_key: str | None = None
    not_modified: bool = False


@dataclass(frozen=True)
class RecommendationItem:
    paper: PaperRecord
    pool: str
    age_bucket: str
    quality_score: float
    trend_score: float
    recommendation_weight: float
    signals: Mapping[str, Any]
