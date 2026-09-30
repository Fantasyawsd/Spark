"""Legacy recommendation snapshot mapping owned by persistence.

The existing batch format is preserved, including timestamps and rounding.
Future API presentation changes must not silently rewrite stored snapshots.
"""
from __future__ import annotations

from typing import Any

from .models import FieldProvenance, PaperRecord, RecommendationItem


def _provenance_to_record(value: FieldProvenance) -> dict[str, Any]:
    return {
        "field_name": value.field_name,
        "source": value.source,
        "fetched_at": value.fetched_at.isoformat().replace("+00:00", "Z"),
        "source_updated_at": value.source_updated_at.isoformat().replace("+00:00", "Z") if value.source_updated_at else None,
        "evidence": dict(value.evidence),
    }


def _paper_to_record(value: PaperRecord) -> dict[str, Any]:
    return {
        "paper_id": value.paper_id,
        "title": value.title,
        "abstract": value.abstract,
        "authors": list(value.authors),
        "published_at": value.published_at.isoformat().replace("+00:00", "Z"),
        "updated_at": value.updated_at.isoformat().replace("+00:00", "Z") if value.updated_at else None,
        "subjects": list(value.subjects),
        "external_ids": dict(value.external_ids),
        "discovery_sources": list(value.discovery_sources),
        "signals": {key: dict(item) for key, item in value.signals.items()},
        "metadata": dict(value.metadata),
        "admitted": value.admitted,
        "admission_reason": value.admission_reason,
        "withdrawn": value.withdrawn,
        "schema_version": value.schema_version,
        "provenance": [_provenance_to_record(item) for item in value.provenance],
    }


def recommendation_to_record(value: RecommendationItem) -> dict[str, Any]:
    payload = _paper_to_record(value.paper)
    payload.update(
        {
            "pool": value.pool,
            "age_bucket": value.age_bucket,
            "quality_score": round(value.quality_score, 6),
            "trend_score": round(value.trend_score, 6),
            "personalization_score": round(value.personalization_score, 6),
            "recommendation_weight": round(value.recommendation_weight, 6),
            "score_signals": dict(value.signals),
        }
    )
    return payload
