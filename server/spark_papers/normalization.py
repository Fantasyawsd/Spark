from __future__ import annotations

from datetime import datetime
from typing import Any, Mapping

from .identity import normalize_arxiv_id, normalize_doi, normalize_external_ids, stable_paper_id
from .models import PaperRecord, parse_datetime
from .policy import AiAdmissionPolicy


def _authors(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()
    if isinstance(value, str):
        return (value.strip(),) if value.strip() else ()
    result: list[str] = []
    for item in value:
        if isinstance(item, Mapping):
            name = item.get("name") or item.get("display_name") or item.get("author_name")
        else:
            name = item
        if name and str(name).strip():
            result.append(str(name).strip())
    return tuple(dict.fromkeys(result))


def _subjects(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()
    if isinstance(value, str):
        value = value.replace(",", " ").split()
    result: list[str] = []
    for item in value:
        if isinstance(item, Mapping):
            item = item.get("id") or item.get("name") or item.get("display_name")
        if item and str(item).strip():
            result.append(str(item).strip())
    return tuple(dict.fromkeys(result))


def _source_ids(source: str, record: Mapping[str, Any]) -> dict[str, str]:
    external = dict(record.get("external_ids") or {})
    for key in ("arxiv_id", "doi", "openalex_id", "semantic_scholar_id", "huggingface_id", "github_url"):
        if record.get(key):
            external[key] = str(record[key])
    if source == "arxiv" and record.get("id"):
        external.setdefault("arxiv_id", str(record["id"]))
    if source == "huggingface" and record.get("id"):
        external.setdefault("huggingface_id", str(record["id"]))
    normalized = normalize_external_ids(external)
    if normalized.get("arxiv_id"):
        normalized["arxiv_id"] = normalize_arxiv_id(normalized["arxiv_id"]) or normalized["arxiv_id"]
    if normalized.get("doi"):
        normalized["doi"] = normalize_doi(normalized["doi"]) or normalized["doi"]
    return normalized


def normalize_record(
    source: str,
    record: Mapping[str, Any],
    *,
    fetched_at: datetime,
    policy: AiAdmissionPolicy,
) -> tuple[PaperRecord, str]:
    title = str(record.get("title") or "").strip()
    if not title:
        raise ValueError(f"{source} record has no title")
    authors = _authors(record.get("authors"))
    published_at = parse_datetime(record.get("published_at") or record.get("publishedAt") or record.get("published"))
    if published_at is None:
        raise ValueError(f"{source} record {title!r} has no published_at")
    external_ids = _source_ids(source, record)
    subjects = _subjects(record.get("subjects") or record.get("categories"))
    signals = {str(key): dict(value) for key, value in (record.get("signals") or {}).items()}
    if source == "huggingface":
        signals.setdefault("huggingface", {}).update(
            {key: record[key] for key in ("heat", "upvotes", "rank") if record.get(key) is not None}
        )
    metadata = dict(record.get("metadata") or {})
    for key in ("venue_name", "venue_type", "venue_year", "venue_url", "track", "pdf_url", "abs_url"):
        if record.get(key) is not None:
            metadata[key] = record[key]
    decision = policy.evaluate(subjects, signals)
    paper_id = stable_paper_id(external_ids, title, authors, published_at.isoformat())
    return (
        PaperRecord(
            paper_id=paper_id,
            title=title,
            abstract=(str(record["abstract"]).strip() if record.get("abstract") is not None else None),
            authors=authors,
            published_at=published_at,
            updated_at=parse_datetime(record.get("updated_at") or record.get("updatedAt")),
            subjects=subjects,
            external_ids=external_ids,
            discovery_sources=(source,),
            signals=signals,
            metadata=metadata,
            admitted=decision.admitted,
            admission_reason=decision.reason,
            withdrawn=bool(record.get("withdrawn", False)),
        ),
        str(record.get("external_id") or next(iter(external_ids.values()), paper_id)),
    )
