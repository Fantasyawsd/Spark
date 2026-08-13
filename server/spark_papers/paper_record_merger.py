from __future__ import annotations

from . import PAPER_SCHEMA_VERSION
from .models import PaperRecord


def merge_paper_records(
    current: PaperRecord,
    incoming: PaperRecord,
    target_id: str,
    *,
    preserve_canonical: bool,
    add_discovery_source: bool,
) -> PaperRecord:
    """Merge source observations without depending on the storage adapter."""
    external_ids = dict(current.external_ids)
    external_ids.update({key: value for key, value in incoming.external_ids.items() if value})
    signals = {key: dict(value) for key, value in current.signals.items()}
    for key, value in incoming.signals.items():
        signals.setdefault(key, {}).update(
            {field: val for field, val in value.items() if val is not None}
        )
    metadata = dict(current.metadata)
    metadata.update({key: value for key, value in incoming.metadata.items() if value is not None})
    title = current.title if preserve_canonical or current.title.strip() else incoming.title
    abstract = (
        current.abstract or incoming.abstract
        if preserve_canonical
        else incoming.abstract or current.abstract
    )
    authors = current.authors or incoming.authors
    published_at = current.published_at if preserve_canonical else min(
        current.published_at,
        incoming.published_at,
    )
    updated_at = (
        current.updated_at
        if preserve_canonical
        else max(filter(None, (current.updated_at, incoming.updated_at)), default=None)
    )
    subjects = current.subjects if preserve_canonical else tuple(
        dict.fromkeys((*current.subjects, *incoming.subjects))
    )
    sources = (
        tuple(dict.fromkeys((*current.discovery_sources, *incoming.discovery_sources)))
        if add_discovery_source
        else current.discovery_sources
    )
    return PaperRecord(
        paper_id=target_id,
        title=title,
        abstract=abstract,
        authors=authors,
        published_at=published_at,
        updated_at=updated_at,
        subjects=subjects,
        external_ids=external_ids,
        discovery_sources=sources,
        signals=signals,
        metadata=metadata,
        admitted=current.admitted or incoming.admitted,
        admission_reason=(
            incoming.admission_reason
            if incoming.admitted and not current.admitted
            else current.admission_reason or incoming.admission_reason
        ),
        withdrawn=current.withdrawn or incoming.withdrawn,
        schema_version=PAPER_SCHEMA_VERSION,
    )
