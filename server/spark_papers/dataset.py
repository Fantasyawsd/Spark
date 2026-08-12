from __future__ import annotations

import json
import math
import uuid
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import Any, Callable, Mapping

from .identity import normalize_arxiv_id
from .models import parse_datetime, utc_now
from .normalization import normalize_record
from .policy import AiAdmissionPolicy
from .storage import PaperStore


UTC = timezone.utc
ProgressCallback = Callable[[Mapping[str, Any]], None]


class DatasetImporter:
    """Streams trusted local dataset files into the canonical Paper Database."""

    def __init__(
        self,
        store: PaperStore,
        *,
        batch_size: int = 500,
        policy: AiAdmissionPolicy | None = None,
        progress: ProgressCallback | None = None,
        lease_seconds: int = 120,
    ) -> None:
        self.store = store
        self.batch_size = max(1, min(int(batch_size), 5000))
        self.policy = policy or AiAdmissionPolicy()
        self.progress = progress
        self.lease_seconds = max(30, int(lease_seconds))
        self.run_token = uuid.uuid4().hex

    def import_arxiv(self, path: str | Path, *, max_records: int | None = None) -> dict[str, Any]:
        source_path = Path(path).resolve()
        return self._import_papers(
            source_path,
            dataset_key=f"arxiv-base:{source_path.name}",
            max_records=max_records,
        )

    def import_venues(self, root: str | Path, *, max_records: int | None = None) -> dict[str, Any]:
        root_path = Path(root).resolve()
        files = sorted(root_path.rglob("*.jsonl"))
        totals = _empty_totals("venues")
        remaining = max_records
        for path in files:
            if remaining is not None and remaining <= 0:
                break
            relative = path.relative_to(root_path).as_posix()
            report = self._import_enrichments(
                path,
                dataset_key=f"arxiv-venue:{relative}",
                source="arxiv_venue",
                mapper=_venue_enrichment,
                max_records=remaining,
            )
            _add_report(totals, report)
            totals["files"] += 1
            if remaining is not None:
                remaining -= int(report.get("processed_this_run", 0))
        if files and totals["files"] == len(files) and remaining is None:
            now = utc_now()
            self.store.record_snapshot(
                "arxiv_venue",
                "venue-tree",
                status="success",
                fetched_at=now,
                raw_path=str(root_path),
                record_count=totals["imported"],
            )
        totals["source_path"] = str(root_path)
        totals["available_files"] = len(files)
        return totals

    def import_openalex(self, path: str | Path, *, max_records: int | None = None) -> dict[str, Any]:
        source_path = Path(path).resolve()
        outlier_threshold = _openalex_outlier_threshold(source_path)

        def mapper(record: Mapping[str, Any]) -> dict[str, Any]:
            return _openalex_enrichment(record, outlier_threshold=outlier_threshold)

        report = self._import_enrichments(
            source_path,
            dataset_key=f"openalex-top:{source_path.name}",
            source="openalex",
            mapper=mapper,
            max_records=max_records,
        )
        report["citation_outlier_threshold"] = outlier_threshold
        return report

    def _import_papers(
        self,
        path: Path,
        *,
        dataset_key: str,
        max_records: int | None,
    ) -> dict[str, Any]:
        state = self._start(path, dataset_key=dataset_key, source="arxiv")
        if state.get("status") == "completed":
            state = self.store.reconcile_arxiv_dataset(dataset_key, str(path))
            return {**state, "processed_this_run": 0, "max_batch_size": 0}
        records: list[Mapping[str, Any]] = []
        rejections: list[Mapping[str, Any]] = []
        processed_this_run = 0
        max_batch_size = 0
        line_number = int(state["line_number"])
        checkpoint_offset = int(state["byte_offset"])
        reached_eof = False
        try:
            with path.open("rb") as handle:
                handle.seek(checkpoint_offset)
                while max_records is None or processed_this_run < max_records:
                    line_offset = handle.tell()
                    raw_line = handle.readline()
                    if not raw_line:
                        reached_eof = True
                        break
                    checkpoint_offset = handle.tell()
                    line_number += 1
                    processed_this_run += 1
                    try:
                        payload = _decode_mapping(raw_line)
                        normalized = normalize_arxiv_dataset_record(payload)
                        fetched_at = utc_now()
                        paper, external_id = normalize_record(
                            "arxiv",
                            normalized,
                            fetched_at=fetched_at,
                            policy=self.policy,
                        )
                        raw_reference = _raw_reference(path, line_number, line_offset)
                        records.append(
                            {
                                "paper": paper,
                                "source": "arxiv",
                                "external_id": external_id,
                                "source_updated_at": paper.updated_at,
                                "raw_payload": raw_reference,
                                "provenance": {
                                    "canonical_fields": {
                                        **raw_reference,
                                        "fields": [
                                            "title",
                                            "abstract",
                                            "authors",
                                            "published_at",
                                            "updated_at",
                                            "subjects",
                                            "external_ids",
                                            "metadata",
                                        ],
                                    },
                                    "missing_fields": {
                                        "fields": _missing_arxiv_fields(payload),
                                        "reason": "not_present_in_source",
                                    },
                                },
                            }
                        )
                    except (json.JSONDecodeError, UnicodeDecodeError, TypeError, ValueError, KeyError) as error:
                        rejections.append(_rejection(line_number, line_offset, error, raw_line))
                    if len(records) + len(rejections) >= self.batch_size:
                        max_batch_size = max(max_batch_size, len(records) + len(rejections))
                        self._flush_papers(
                            dataset_key,
                            records,
                            rejections,
                            checkpoint_offset,
                            line_number,
                        )
                if records or rejections:
                    max_batch_size = max(max_batch_size, len(records) + len(rejections))
                    self._flush_papers(
                        dataset_key,
                        records,
                        rejections,
                        checkpoint_offset,
                        line_number,
                    )
            if reached_eof:
                completed_at = utc_now()
                state = self.store.complete_dataset_import(
                    dataset_key,
                    completed_at,
                    run_token=self.run_token,
                )
                state = self.store.reconcile_arxiv_dataset(dataset_key, str(path))
                self.store.record_snapshot(
                    "arxiv",
                    dataset_key,
                    status="success",
                    fetched_at=completed_at,
                    raw_path=str(path),
                    record_count=int(state["imported_count"]),
                )
            else:
                state = self.store.pause_dataset_import(
                    dataset_key,
                    utc_now(),
                    run_token=self.run_token,
                )
        except Exception as error:
            self.store.fail_dataset_import(dataset_key, str(error), utc_now(), run_token=self.run_token)
            raise
        return {**state, "processed_this_run": processed_this_run, "max_batch_size": max_batch_size}

    def _import_enrichments(
        self,
        path: Path,
        *,
        dataset_key: str,
        source: str,
        mapper: Callable[[Mapping[str, Any]], dict[str, Any]],
        max_records: int | None,
    ) -> dict[str, Any]:
        state = self._start(path, dataset_key=dataset_key, source=source)
        if state.get("status") == "completed":
            return {**state, "processed_this_run": 0, "max_batch_size": 0}
        records: list[Mapping[str, Any]] = []
        rejections: list[Mapping[str, Any]] = []
        processed_this_run = 0
        max_batch_size = 0
        line_number = int(state["line_number"])
        checkpoint_offset = int(state["byte_offset"])
        reached_eof = False
        try:
            with path.open("rb") as handle:
                handle.seek(checkpoint_offset)
                while max_records is None or processed_this_run < max_records:
                    line_offset = handle.tell()
                    raw_line = handle.readline()
                    if not raw_line:
                        reached_eof = True
                        break
                    checkpoint_offset = handle.tell()
                    line_number += 1
                    processed_this_run += 1
                    try:
                        item = mapper(_decode_mapping(raw_line))
                        raw_reference = _raw_reference(path, line_number, line_offset)
                        records.append(
                            {
                                **item,
                                "source": source,
                                "raw_payload": raw_reference,
                                "provenance": {
                                    **item.get("provenance", {}),
                                    "source_record": raw_reference,
                                },
                            }
                        )
                    except (json.JSONDecodeError, UnicodeDecodeError, TypeError, ValueError, KeyError) as error:
                        rejections.append(_rejection(line_number, line_offset, error, raw_line))
                    if len(records) + len(rejections) >= self.batch_size:
                        max_batch_size = max(max_batch_size, len(records) + len(rejections))
                        self._flush_enrichments(
                            dataset_key,
                            records,
                            rejections,
                            checkpoint_offset,
                            line_number,
                        )
                if records or rejections:
                    max_batch_size = max(max_batch_size, len(records) + len(rejections))
                    self._flush_enrichments(
                        dataset_key,
                        records,
                        rejections,
                        checkpoint_offset,
                        line_number,
                    )
            if reached_eof:
                completed_at = utc_now()
                state = self.store.complete_dataset_import(
                    dataset_key,
                    completed_at,
                    run_token=self.run_token,
                )
                self.store.record_snapshot(
                    source,
                    dataset_key,
                    status="success",
                    fetched_at=completed_at,
                    raw_path=str(path),
                    record_count=int(state["imported_count"]),
                )
            else:
                state = self.store.pause_dataset_import(
                    dataset_key,
                    utc_now(),
                    run_token=self.run_token,
                )
        except Exception as error:
            self.store.fail_dataset_import(dataset_key, str(error), utc_now(), run_token=self.run_token)
            raise
        return {**state, "processed_this_run": processed_this_run, "max_batch_size": max_batch_size}

    def _start(self, path: Path, *, dataset_key: str, source: str) -> dict[str, Any]:
        stat = path.stat()
        return self.store.start_dataset_import(
            dataset_key=dataset_key,
            source=source,
            source_path=str(path),
            source_size=stat.st_size,
            source_mtime_ns=stat.st_mtime_ns,
            started_at=utc_now(),
            run_token=self.run_token,
            lease_seconds=self.lease_seconds,
        )

    def _flush_papers(
        self,
        dataset_key: str,
        records: list[Mapping[str, Any]],
        rejections: list[Mapping[str, Any]],
        byte_offset: int,
        line_number: int,
    ) -> None:
        result = self.store.apply_dataset_paper_batch(
            dataset_key=dataset_key,
            records=records,
            rejections=rejections,
            byte_offset=byte_offset,
            line_number=line_number,
            fetched_at=utc_now(),
            run_token=self.run_token,
            lease_seconds=self.lease_seconds,
        )
        self._notify(dataset_key, line_number, result)
        records.clear()
        rejections.clear()

    def _flush_enrichments(
        self,
        dataset_key: str,
        records: list[Mapping[str, Any]],
        rejections: list[Mapping[str, Any]],
        byte_offset: int,
        line_number: int,
    ) -> None:
        result = self.store.apply_dataset_enrichment_batch(
            dataset_key=dataset_key,
            records=records,
            rejections=rejections,
            byte_offset=byte_offset,
            line_number=line_number,
            fetched_at=utc_now(),
            run_token=self.run_token,
            lease_seconds=self.lease_seconds,
        )
        self._notify(dataset_key, line_number, result)
        records.clear()
        rejections.clear()

    def _notify(self, dataset_key: str, line_number: int, result: Mapping[str, Any]) -> None:
        if self.progress is not None:
            self.progress({"dataset_key": dataset_key, "line_number": line_number, **result})


def normalize_arxiv_dataset_record(record: Mapping[str, Any]) -> dict[str, Any]:
    arxiv_id = normalize_arxiv_id(str(record.get("id") or record.get("arxiv_id") or ""))
    if not arxiv_id:
        raise ValueError("arXiv dataset record has no id")
    versions = record.get("versions") or []
    if not isinstance(versions, list) or not versions:
        raise ValueError(f"arXiv dataset record {arxiv_id} has no versions")
    first_created = versions[0].get("created") if isinstance(versions[0], Mapping) else None
    published_at = _parse_arxiv_created(first_created)
    if published_at is None:
        raise ValueError(f"arXiv dataset record {arxiv_id} has invalid first version date")
    authors_parsed = record.get("authors_parsed")
    authors = _structured_authors(authors_parsed)
    if not authors:
        raw_authors = _clean_text(record.get("authors"))
        authors = [raw_authors] if raw_authors else []
    updated_at = parse_datetime(record.get("update_date"))
    arxiv_metadata = {
        "authors_parsed": authors_parsed if isinstance(authors_parsed, list) else [],
        "comments": _nullable_text(record.get("comments")),
        "journal_ref": _nullable_text(record.get("journal-ref")),
        "report_no": _nullable_text(record.get("report-no")),
        "license": _nullable_text(record.get("license")),
        "versions": versions,
        "submitter": _nullable_text(record.get("submitter")),
    }
    return {
        "id": arxiv_id,
        "external_id": arxiv_id,
        "arxiv_id": arxiv_id,
        "doi": record.get("doi"),
        "title": _clean_text(record.get("title")),
        "abstract": _nullable_text(record.get("abstract")),
        "authors": authors,
        "published_at": published_at.isoformat(),
        "updated_at": updated_at.isoformat() if updated_at else None,
        "categories": record.get("categories"),
        "pdf_url": f"https://arxiv.org/pdf/{arxiv_id}",
        "abs_url": f"https://arxiv.org/abs/{arxiv_id}",
        "metadata": {"arxiv": arxiv_metadata},
    }


def _venue_enrichment(record: Mapping[str, Any]) -> dict[str, Any]:
    arxiv_id = normalize_arxiv_id(str(record.get("id") or record.get("arxiv_id") or ""))
    if not arxiv_id:
        raise ValueError("venue record has no arXiv id")
    raw_venues = record.get("_matched_venue")
    if isinstance(raw_venues, str):
        venue_matches = [raw_venues.strip()] if raw_venues.strip() else []
    elif isinstance(raw_venues, list):
        venue_matches = [str(item).strip() for item in raw_venues if str(item).strip()]
    else:
        venue_matches = []
    if not venue_matches:
        raise ValueError(f"venue record {arxiv_id} has no matched venue")
    raw_label = _nullable_text(record.get("_matched_label"))
    venue_label = None if raw_label is None or raw_label.lower() == "none" else raw_label
    metadata: dict[str, Any] = {
        "venue_name": venue_matches[0],
        "venue_type": "conference",
        "venue_matches": venue_matches,
        "venue_label": venue_label,
    }
    return {
        "lookup_value": arxiv_id,
        "external_id": arxiv_id,
        "external_ids": {},
        "signals": {},
        "metadata": metadata,
        "provenance": {
            "venue": {
                "match_method": "comments_or_journal_ref_regex",
                "venue_matches": venue_matches,
                "venue_label": venue_label,
                "venue_year": None,
            }
        },
    }


def _openalex_enrichment(record: Mapping[str, Any], *, outlier_threshold: int | None) -> dict[str, Any]:
    arxiv_id = normalize_arxiv_id(str(record.get("arxiv_id") or ""))
    if not arxiv_id:
        raise ValueError("OpenAlex enrichment has no arXiv id")
    openalex_id = _normalize_openalex_id(record.get("openalex_id"))
    citation_count = _optional_non_negative_int(record.get("cited_by_count"))
    fwci = _optional_float(record.get("fwci"))
    match_method = _nullable_text(record.get("via"))
    is_outlier = bool(
        citation_count is not None
        and outlier_threshold is not None
        and citation_count > outlier_threshold
    )
    signal = {
        "citation_count": citation_count,
        "fwci": fwci,
        "match_method": match_method,
        "citation_count_outlier": is_outlier,
    }
    metadata = {
        "openalex": {
            "publication_year": _optional_non_negative_int(record.get("publication_year")),
        }
    }
    return {
        "lookup_value": arxiv_id,
        "external_id": openalex_id or arxiv_id,
        "external_ids": {"openalex_id": openalex_id} if openalex_id else {},
        "signals": {"openalex": signal},
        "metadata": metadata,
        "provenance": {
            "signals.openalex": {
                "match_method": match_method,
                "arxiv_id": arxiv_id,
                "openalex_id": openalex_id,
            }
        },
    }


def _openalex_outlier_threshold(path: Path) -> int | None:
    values: list[int] = []
    with path.open("rb") as handle:
        for raw_line in handle:
            if not raw_line.strip():
                continue
            try:
                value = _optional_non_negative_int(_decode_mapping(raw_line).get("cited_by_count"))
            except (json.JSONDecodeError, UnicodeDecodeError, TypeError, ValueError):
                continue
            if value is not None:
                values.append(value)
    if not values:
        return None
    values.sort()
    return values[max(0, min(len(values) - 1, math.ceil(len(values) * 0.99) - 1))]


def _parse_arxiv_created(value: Any) -> datetime | None:
    if value is None:
        return None
    try:
        parsed = parsedate_to_datetime(str(value))
    except (TypeError, ValueError, OverflowError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC).replace(microsecond=0)


def _structured_authors(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    result: list[str] = []
    for item in value:
        if not isinstance(item, list) or not item:
            continue
        family = str(item[0]).strip() if len(item) > 0 and item[0] else ""
        given = str(item[1]).strip() if len(item) > 1 and item[1] else ""
        suffix = str(item[2]).strip() if len(item) > 2 and item[2] else ""
        name = " ".join(part for part in (given, family, suffix) if part)
        if name and name not in result:
            result.append(name)
    return result


def _clean_text(value: Any) -> str:
    return " ".join(str(value or "").split())


def _nullable_text(value: Any) -> str | None:
    text = _clean_text(value)
    return text or None


def _decode_mapping(raw_line: bytes) -> Mapping[str, Any]:
    payload = json.loads(raw_line.decode("utf-8"))
    if not isinstance(payload, Mapping):
        raise ValueError("JSONL line is not an object")
    return payload


def _raw_reference(path: Path, line_number: int, byte_offset: int) -> dict[str, Any]:
    return {
        "source_path": str(path),
        "line_number": line_number,
        "byte_offset": byte_offset,
    }


def _rejection(line_number: int, byte_offset: int, error: Exception, raw_line: bytes) -> dict[str, Any]:
    return {
        "line_number": line_number,
        "byte_offset": byte_offset,
        "error": f"{type(error).__name__}: {error}",
        "payload_excerpt": raw_line[:1000].decode("utf-8", errors="replace"),
    }


def _missing_arxiv_fields(record: Mapping[str, Any]) -> list[str]:
    fields = {
        "abstract": "abstract",
        "authors": "authors_parsed",
        "updated_at": "update_date",
        "subjects": "categories",
        "doi": "doi",
        "comments": "comments",
        "journal_ref": "journal-ref",
        "license": "license",
    }
    return [name for name, source_key in fields.items() if record.get(source_key) in (None, "", [])]


def _normalize_openalex_id(value: Any) -> str | None:
    text = _nullable_text(value)
    if text is None:
        return None
    return text.rsplit("/", 1)[-1]


def _optional_non_negative_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    parsed = int(value)
    return parsed if parsed >= 0 else None


def _optional_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    return float(value)


def _empty_totals(stage: str) -> dict[str, Any]:
    return {
        "stage": stage,
        "files": 0,
        "processed": 0,
        "imported": 0,
        "duplicates": 0,
        "rejected": 0,
        "unmatched": 0,
        "processed_this_run": 0,
        "max_batch_size": 0,
    }


def _add_report(totals: dict[str, Any], report: Mapping[str, Any]) -> None:
    totals["processed"] += int(report.get("processed_count", 0))
    totals["imported"] += int(report.get("imported_count", 0))
    totals["duplicates"] += int(report.get("duplicate_count", 0))
    totals["rejected"] += int(report.get("rejected_count", 0))
    totals["unmatched"] += int(report.get("unmatched_count", 0))
    totals["processed_this_run"] += int(report.get("processed_this_run", 0))
    totals["max_batch_size"] = max(totals["max_batch_size"], int(report.get("max_batch_size", 0)))
