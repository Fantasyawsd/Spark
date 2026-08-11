from __future__ import annotations

from datetime import datetime
from typing import Any, Iterable, Mapping, Protocol

from .models import PaperRecord


class PaperRepository(Protocol):
    def get(self, paper_id: str) -> PaperRecord | None: ...
    def count(self) -> int: ...
    def all_candidates(self) -> list[PaperRecord]: ...
    def recommendation_candidates(
        self,
        *,
        read_ids: Iterable[str] = (),
        per_pool_limit: int = 500,
        as_of: datetime | None = None,
    ) -> list[PaperRecord]: ...

    def list_papers(
        self,
        *,
        limit: int = 20,
        cursor: tuple[str, str] | None = None,
        subject: str | None = None,
        venue: str | None = None,
        venue_year: int | None = None,
        track: str | None = None,
        from_date: datetime | None = None,
        to_date: datetime | None = None,
        sort: str = "latest",
        admitted_only: bool = True,
        sources: Iterable[str] = (),
    ) -> tuple[list[PaperRecord], tuple[str, str] | None]: ...

    def list_following(
        self,
        *,
        authors: Iterable[str],
        subjects: Iterable[str],
        venues: Iterable[str],
        limit: int,
        cursor: tuple[str, str] | None = None,
    ) -> tuple[list[PaperRecord], tuple[str, str] | None]: ...


class PipelineRepository(PaperRepository, Protocol):
    def ingest(
        self,
        paper: PaperRecord,
        *,
        source: str,
        external_id: str,
        raw_payload: Mapping[str, Any],
        fetched_at: datetime,
        source_updated_at: datetime | None = None,
        etag: str | None = None,
    ) -> str: ...

    def get_sync_state(self, source: str) -> dict[str, str | None]: ...
    def record_snapshot(self, source: str, snapshot_key: str, **kwargs: Any) -> None: ...
    def set_sync_state(self, source: str, etag: str | None, cursor: str | None, path: str | None, at: datetime) -> None: ...
    def refresh_indexes(self, generated_at: datetime | None = None) -> None: ...


class RecommendationRepository(PaperRepository, Protocol):
    def record_batch(
        self,
        batch_id: str,
        generated_at: datetime,
        score_version: str,
        sampling_seed: int,
        feature_snapshot: Mapping[str, Any],
        selected_paper_ids: list[str],
    ) -> None: ...
