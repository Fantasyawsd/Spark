from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable, Iterator, Mapping

from . import PAPER_SCHEMA_VERSION
from .identity import fuzzy_identity_score, normalize_external_ids, stable_paper_id
from .db_mapper import paper_from_row, paper_values
from .models import PaperRecord, parse_datetime, utc_now


def _json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":"))


def _load(value: str | None, fallback: Any) -> Any:
    if value is None:
        return fallback
    return json.loads(value)


class PaperStore:
    """SQLite persistence for canonical papers and source observations."""

    def __init__(self, path: str | Path = ":memory:") -> None:
        self.path = str(path)
        if self.path != ":memory:":
            Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(self.path, check_same_thread=False)
        self._connection.row_factory = sqlite3.Row
        self._connection.execute("PRAGMA foreign_keys = ON")
        self._connection.execute("PRAGMA journal_mode = WAL")
        self._create_schema()

    def close(self) -> None:
        self._connection.close()

    @contextmanager
    def transaction(self) -> Iterator[sqlite3.Connection]:
        try:
            yield self._connection
            self._connection.commit()
        except Exception:
            self._connection.rollback()
            raise

    def _create_schema(self) -> None:
        self._connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS papers (
                paper_id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                abstract TEXT,
                authors_json TEXT NOT NULL,
                published_at TEXT NOT NULL,
                updated_at TEXT,
                subjects_json TEXT NOT NULL,
                external_ids_json TEXT NOT NULL,
                discovery_sources_json TEXT NOT NULL,
                signals_json TEXT NOT NULL,
                metadata_json TEXT NOT NULL,
                admitted INTEGER NOT NULL,
                admission_reason TEXT NOT NULL,
                withdrawn INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                last_seen_at TEXT NOT NULL,
                schema_version TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_papers_published ON papers (published_at DESC, paper_id DESC);
            CREATE INDEX IF NOT EXISTS idx_papers_admitted ON papers (admitted, withdrawn, published_at DESC);

            CREATE TABLE IF NOT EXISTS source_observations (
                source TEXT NOT NULL,
                external_id TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                payload_json TEXT NOT NULL,
                source_updated_at TEXT,
                fetched_at TEXT NOT NULL,
                etag TEXT,
                PRIMARY KEY (source, external_id)
            );
            CREATE INDEX IF NOT EXISTS idx_observations_paper ON source_observations (paper_id);

            CREATE TABLE IF NOT EXISTS provenance (
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                field_name TEXT NOT NULL,
                source TEXT NOT NULL,
                fetched_at TEXT NOT NULL,
                source_updated_at TEXT,
                evidence_json TEXT NOT NULL,
                PRIMARY KEY (paper_id, field_name, source)
            );

            CREATE TABLE IF NOT EXISTS snapshots (
                source TEXT NOT NULL,
                snapshot_key TEXT NOT NULL,
                fetched_at TEXT NOT NULL,
                status TEXT NOT NULL,
                etag TEXT,
                cursor TEXT,
                raw_path TEXT,
                record_count INTEGER NOT NULL DEFAULT 0,
                error TEXT,
                PRIMARY KEY (source, snapshot_key)
            );

            CREATE TABLE IF NOT EXISTS sync_state (
                source TEXT PRIMARY KEY,
                etag TEXT,
                cursor TEXT,
                last_success_at TEXT,
                last_snapshot_path TEXT
            );

            CREATE TABLE IF NOT EXISTS match_queue (
                queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
                source TEXT NOT NULL,
                external_id TEXT NOT NULL,
                candidate_paper_id TEXT,
                confidence REAL NOT NULL,
                reason TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                resolved_at TEXT
            );

            CREATE TABLE IF NOT EXISTS recommendation_batches (
                batch_id TEXT PRIMARY KEY,
                generated_at TEXT NOT NULL,
                score_version TEXT NOT NULL,
                sampling_seed INTEGER NOT NULL,
                feature_snapshot_json TEXT NOT NULL,
                selected_paper_ids_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS latest_index (
                paper_id TEXT PRIMARY KEY REFERENCES papers(paper_id),
                published_at TEXT NOT NULL,
                generated_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_latest_index_order ON latest_index (published_at DESC, paper_id DESC);

            CREATE TABLE IF NOT EXISTS channel_index (
                channel_key TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                sort_key TEXT NOT NULL,
                generated_at TEXT NOT NULL,
                PRIMARY KEY (channel_key, paper_id)
            );
            CREATE INDEX IF NOT EXISTS idx_channel_index_order ON channel_index (channel_key, sort_key DESC, paper_id DESC);

            CREATE TABLE IF NOT EXISTS candidate_index (
                pool TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                generated_at TEXT NOT NULL,
                PRIMARY KEY (pool, paper_id)
            );

            CREATE TABLE IF NOT EXISTS schema_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        self._connection.execute(
            "INSERT OR IGNORE INTO schema_meta(key, value, updated_at) VALUES ('paper_schema', ?, ?)",
            (PAPER_SCHEMA_VERSION, utc_now().isoformat()),
        )
        self._connection.commit()

    def _row_to_paper(self, row: sqlite3.Row) -> PaperRecord:
        provenance_rows = self._connection.execute(
            "SELECT * FROM provenance WHERE paper_id = ? ORDER BY field_name, source", (row["paper_id"],)
        ).fetchall()
        return paper_from_row(row, provenance_rows)

    def get(self, paper_id: str) -> PaperRecord | None:
        row = self._connection.execute("SELECT * FROM papers WHERE paper_id = ?", (paper_id,)).fetchone()
        return self._row_to_paper(row) if row else None

    def count(self) -> int:
        return int(self._connection.execute("SELECT COUNT(*) FROM papers").fetchone()[0])

    def find_by_external_ids(self, external_ids: Mapping[str, str]) -> set[str]:
        matches: set[str] = set()
        for key, value in normalize_external_ids(external_ids).items():
            rows = self._connection.execute(
                "SELECT paper_id, external_ids_json FROM papers WHERE json_extract(external_ids_json, ?) = ?",
                (f"$.{key}", value),
            ).fetchall()
            matches.update(row["paper_id"] for row in rows)
        return matches

    def find_fuzzy_candidates(self, title: str, author: str, limit: int = 5) -> list[tuple[str, float]]:
        rows = self._connection.execute("SELECT paper_id, title, authors_json FROM papers").fetchall()
        scored = [
            (row["paper_id"], fuzzy_identity_score(title, row["title"], author, (_load(row["authors_json"], [""]) or [""])[0]))
            for row in rows
        ]
        return sorted(scored, key=lambda item: item[1], reverse=True)[:limit]

    def queue_match(
        self,
        source: str,
        external_id: str,
        candidate_paper_id: str | None,
        confidence: float,
        reason: str,
        payload: Mapping[str, Any],
    ) -> None:
        self._connection.execute(
            """INSERT INTO match_queue
               (source, external_id, candidate_paper_id, confidence, reason, payload_json, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (source, external_id, candidate_paper_id, confidence, reason, _json(payload), utc_now().isoformat()),
        )
        self._connection.commit()

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
    ) -> str:
        existing_ids = self.find_by_external_ids(paper.external_ids)
        target_id = paper.paper_id
        if len(existing_ids) == 1:
            target_id = next(iter(existing_ids))
        elif len(existing_ids) > 1:
            self.queue_match(source, external_id, None, 1.0, "conflicting_exact_identity", raw_payload)
            return paper.paper_id
        elif not existing_ids:
            fuzzy = self.find_fuzzy_candidates(paper.title, paper.authors[0] if paper.authors else "", limit=1)
            if fuzzy and fuzzy[0][1] >= 0.65:
                self.queue_match(source, external_id, fuzzy[0][0], fuzzy[0][1], "fuzzy_candidate_requires_review", raw_payload)
        current = self.get(target_id)
        if current is None:
            merged = paper if target_id == paper.paper_id else PaperRecord(
                paper_id=target_id,
                title=paper.title,
                abstract=paper.abstract,
                authors=paper.authors,
                published_at=paper.published_at,
                updated_at=paper.updated_at,
                subjects=paper.subjects,
                external_ids=paper.external_ids,
                discovery_sources=paper.discovery_sources,
                signals=paper.signals,
                metadata=paper.metadata,
                admitted=paper.admitted,
                admission_reason=paper.admission_reason,
                withdrawn=paper.withdrawn,
            )
            created_at = fetched_at
        else:
            merged = self._merge(current, paper, target_id)
            created_at = parse_datetime(self._connection.execute(
                "SELECT created_at FROM papers WHERE paper_id = ?", (target_id,)
            ).fetchone()[0]) or fetched_at
        with self.transaction() as connection:
            connection.execute(
                """INSERT INTO papers
                   (paper_id, title, abstract, authors_json, published_at, updated_at,
                    subjects_json, external_ids_json, discovery_sources_json, signals_json,
                    metadata_json, admitted, admission_reason, withdrawn, created_at,
                    last_seen_at, schema_version)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(paper_id) DO UPDATE SET
                    title=excluded.title, abstract=excluded.abstract,
                    authors_json=excluded.authors_json, published_at=excluded.published_at,
                    updated_at=excluded.updated_at, subjects_json=excluded.subjects_json,
                    external_ids_json=excluded.external_ids_json,
                    discovery_sources_json=excluded.discovery_sources_json,
                    signals_json=excluded.signals_json, metadata_json=excluded.metadata_json,
                    admitted=excluded.admitted, admission_reason=excluded.admission_reason,
                    withdrawn=excluded.withdrawn, last_seen_at=excluded.last_seen_at,
                    schema_version=excluded.schema_version""",
                paper_values(merged, created_at, fetched_at),
            )
            connection.execute(
                """INSERT INTO source_observations
                   (source, external_id, paper_id, payload_json, source_updated_at, fetched_at, etag)
                   VALUES (?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(source, external_id) DO UPDATE SET
                    paper_id=excluded.paper_id, payload_json=excluded.payload_json,
                    source_updated_at=excluded.source_updated_at, fetched_at=excluded.fetched_at,
                    etag=excluded.etag""",
                (
                    source,
                    external_id,
                    merged.paper_id,
                    _json(raw_payload),
                    source_updated_at.isoformat() if source_updated_at else None,
                    fetched_at.isoformat(),
                    etag,
                ),
            )
            provenance_fields = _provenance_fields(merged)
            provenance_fields["missing_fields"] = _source_missing_fields(raw_payload)
            for field_name, evidence in provenance_fields.items():
                connection.execute(
                    """INSERT INTO provenance
                       (paper_id, field_name, source, fetched_at, source_updated_at, evidence_json)
                       VALUES (?, ?, ?, ?, ?, ?)
                       ON CONFLICT(paper_id, field_name, source) DO UPDATE SET
                        fetched_at=excluded.fetched_at, source_updated_at=excluded.source_updated_at,
                        evidence_json=excluded.evidence_json""",
                    (
                        merged.paper_id,
                        field_name,
                        source,
                        fetched_at.isoformat(),
                        source_updated_at.isoformat() if source_updated_at else None,
                        _json(evidence),
                    ),
                )
        return merged.paper_id

    def _merge(self, current: PaperRecord, incoming: PaperRecord, target_id: str) -> PaperRecord:
        external_ids = dict(current.external_ids)
        external_ids.update({key: value for key, value in incoming.external_ids.items() if value})
        signals = {key: dict(value) for key, value in current.signals.items()}
        for key, value in incoming.signals.items():
            signals.setdefault(key, {}).update({field: val for field, val in value.items() if val is not None})
        metadata = dict(current.metadata)
        metadata.update({key: value for key, value in incoming.metadata.items() if value is not None})
        title = current.title if current.title.strip() else incoming.title
        abstract = incoming.abstract or current.abstract
        authors = current.authors or incoming.authors
        published_at = min(current.published_at, incoming.published_at)
        updated_at = max(filter(None, (current.updated_at, incoming.updated_at)), default=None)
        subjects = tuple(dict.fromkeys((*current.subjects, *incoming.subjects)))
        sources = tuple(dict.fromkeys((*current.discovery_sources, *incoming.discovery_sources)))
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
            admission_reason=(incoming.admission_reason if incoming.admitted and not current.admitted else current.admission_reason or incoming.admission_reason),
            withdrawn=current.withdrawn or incoming.withdrawn,
            schema_version=PAPER_SCHEMA_VERSION,
        )

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
    ) -> tuple[list[PaperRecord], tuple[str, str] | None]:
        clauses = ["withdrawn = 0"]
        params: list[Any] = []
        if admitted_only:
            clauses.append("admitted = 1")
        if from_date:
            clauses.append("published_at >= ?")
            params.append(from_date.isoformat())
        if to_date:
            clauses.append("published_at <= ?")
            params.append(to_date.isoformat())
        if venue:
            clauses.append("lower(json_extract(metadata_json, '$.venue_name')) = lower(?)")
            params.append(venue)
        if venue_year is not None:
            clauses.append("CAST(json_extract(metadata_json, '$.venue_year') AS INTEGER) = ?")
            params.append(venue_year)
        if track:
            clauses.append("lower(json_extract(metadata_json, '$.track')) = lower(?)")
            params.append(track)
        source_values = tuple(dict.fromkeys(str(value) for value in sources if str(value)))
        if source_values:
            placeholders = ",".join("?" for _ in source_values)
            clauses.append(f"EXISTS (SELECT 1 FROM json_each(papers.discovery_sources_json) WHERE value IN ({placeholders}))")
            params.extend(source_values)
        if subject:
            clauses.append("EXISTS (SELECT 1 FROM json_each(papers.subjects_json) WHERE lower(value) = lower(?))")
            params.append(subject)
        if cursor:
            clauses.append("(published_at < ? OR (published_at = ? AND paper_id < ?))")
            params.extend((cursor[0], cursor[0], cursor[1]))
        order = "published_at DESC, paper_id DESC"
        if sort == "quality":
            order = "json_extract(signals_json, '$.openalex.citation_count') DESC, published_at DESC, paper_id DESC"
        query = f"SELECT * FROM papers WHERE {' AND '.join(clauses)} ORDER BY {order} LIMIT ?"
        params.append(max(1, min(limit, 100)) + 1)
        rows = self._connection.execute(query, params).fetchall()
        items = [self._row_to_paper(row) for row in rows[:limit]]
        next_cursor = None
        if len(rows) > limit and items:
            next_cursor = (items[-1].published_at.isoformat(), items[-1].paper_id)
        return items, next_cursor

    def list_following(
        self,
        *,
        authors: Iterable[str],
        subjects: Iterable[str],
        venues: Iterable[str],
        limit: int,
        cursor: tuple[str, str] | None = None,
    ) -> tuple[list[PaperRecord], tuple[str, str] | None]:
        wanted_authors = {str(item).lower() for item in authors}
        wanted_subjects = {str(item).lower() for item in subjects}
        wanted_venues = {str(item).lower() for item in venues}
        rows = self._connection.execute(
            "SELECT * FROM papers WHERE admitted = 1 AND withdrawn = 0 ORDER BY published_at DESC, paper_id DESC"
        ).fetchall()
        items: list[PaperRecord] = []
        for row in rows:
            paper = self._row_to_paper(row)
            key = (paper.published_at.isoformat(), paper.paper_id)
            if cursor and not (key[0] < cursor[0] or (key[0] == cursor[0] and key[1] < cursor[1])):
                continue
            author_match = wanted_authors.intersection(author.lower() for author in paper.authors)
            subject_match = wanted_subjects.intersection(subject.lower() for subject in paper.subjects)
            venue_match = str(paper.metadata.get("venue_name", "")).lower() in wanted_venues
            if not (author_match or subject_match or (wanted_venues and venue_match)):
                continue
            items.append(paper)
            if len(items) > min(limit, 100):
                break
        bounded = items[: min(limit, 100)]
        next_cursor = None
        if len(items) > len(bounded) and bounded:
            next_cursor = (bounded[-1].published_at.isoformat(), bounded[-1].paper_id)
        return bounded, next_cursor

    def refresh_indexes(self, generated_at: datetime | None = None) -> None:
        generated_at = generated_at or utc_now()
        with self.transaction() as connection:
            connection.execute("DELETE FROM latest_index")
            connection.execute("DELETE FROM channel_index")
            connection.execute("DELETE FROM candidate_index")
            rows = connection.execute("SELECT * FROM papers WHERE admitted = 1 AND withdrawn = 0").fetchall()
            for row in rows:
                paper = self._row_to_paper(row)
                if set(paper.discovery_sources).intersection({"arxiv", "huggingface"}):
                    connection.execute(
                        "INSERT INTO latest_index(paper_id, published_at, generated_at) VALUES (?, ?, ?)",
                        (paper.paper_id, paper.published_at.isoformat(), generated_at.isoformat()),
                    )
                for subject in paper.subjects:
                    connection.execute(
                        "INSERT OR REPLACE INTO channel_index(channel_key, paper_id, sort_key, generated_at) VALUES (?, ?, ?, ?)",
                        (f"subject:{subject}", paper.paper_id, paper.published_at.isoformat(), generated_at.isoformat()),
                    )
                connection.execute(
                    "INSERT INTO candidate_index(pool, paper_id, generated_at) VALUES ('all', ?, ?)",
                    (paper.paper_id, generated_at.isoformat()),
                )

    def all_candidates(self) -> list[PaperRecord]:
        rows = self._connection.execute(
            "SELECT * FROM papers WHERE admitted = 1 AND withdrawn = 0 ORDER BY published_at DESC, paper_id DESC"
        ).fetchall()
        return [self._row_to_paper(row) for row in rows]

    def record_snapshot(
        self,
        source: str,
        snapshot_key: str,
        *,
        status: str,
        fetched_at: datetime,
        etag: str | None = None,
        cursor: str | None = None,
        raw_path: str | None = None,
        record_count: int = 0,
        error: str | None = None,
    ) -> None:
        with self.transaction() as connection:
            connection.execute(
                """INSERT INTO snapshots
                   (source, snapshot_key, fetched_at, status, etag, cursor, raw_path, record_count, error)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(source, snapshot_key) DO UPDATE SET
                    fetched_at=excluded.fetched_at, status=excluded.status, etag=excluded.etag,
                    cursor=excluded.cursor, raw_path=excluded.raw_path,
                    record_count=excluded.record_count, error=excluded.error""",
                (source, snapshot_key, fetched_at.isoformat(), status, etag, cursor, raw_path, record_count, error),
            )

    def set_sync_state(self, source: str, etag: str | None, cursor: str | None, path: str | None, at: datetime) -> None:
        self._connection.execute(
            """INSERT INTO sync_state(source, etag, cursor, last_success_at, last_snapshot_path)
               VALUES (?, ?, ?, ?, ?)
               ON CONFLICT(source) DO UPDATE SET etag=excluded.etag, cursor=excluded.cursor,
               last_success_at=excluded.last_success_at, last_snapshot_path=excluded.last_snapshot_path""",
            (source, etag, cursor, at.isoformat(), path),
        )
        self._connection.commit()

    def get_sync_state(self, source: str) -> dict[str, str | None]:
        row = self._connection.execute("SELECT * FROM sync_state WHERE source = ?", (source,)).fetchone()
        if not row:
            return {"etag": None, "cursor": None, "last_success_at": None, "last_snapshot_path": None}
        return dict(row)

    def record_batch(
        self,
        batch_id: str,
        generated_at: datetime,
        score_version: str,
        sampling_seed: int,
        feature_snapshot: Mapping[str, Any],
        selected_paper_ids: list[str],
    ) -> None:
        self._connection.execute(
            """INSERT OR REPLACE INTO recommendation_batches
               (batch_id, generated_at, score_version, sampling_seed, feature_snapshot_json, selected_paper_ids_json)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (batch_id, generated_at.isoformat(), score_version, sampling_seed, _json(feature_snapshot), _json(selected_paper_ids)),
        )
        self._connection.commit()


def _provenance_fields(paper: PaperRecord) -> dict[str, Any]:
    fields: dict[str, Any] = {
        "title": {"value": paper.title},
        "abstract": {"present": paper.abstract is not None},
        "authors": {"count": len(paper.authors)},
        "published_at": {"value": paper.published_at.isoformat()},
        "subjects": {"values": list(paper.subjects)},
        "external_ids": {"keys": sorted(paper.external_ids)},
        "signals": {"sources": sorted(paper.signals)},
    }
    return fields


def _source_missing_fields(payload: Mapping[str, Any]) -> dict[str, Any]:
    aliases = {
        "abstract": ("abstract", "summary"),
        "authors": ("authors", "authorships"),
        "published_at": ("published_at", "publishedAt", "published", "publication_date", "publicationDate"),
        "updated_at": ("updated_at", "updatedAt", "updated", "updated_date"),
        "subjects": ("subjects", "categories", "fieldsOfStudy"),
        "doi": ("doi",),
    }
    missing = [field_name for field_name, keys in aliases.items() if not any(payload.get(key) is not None for key in keys)]
    return {"fields": missing, "reason": "not_present_in_source"}
