from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta
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


def _merge_nested(current: Mapping[str, Any], incoming: Mapping[str, Any]) -> dict[str, Any]:
    merged = dict(current)
    for key, value in incoming.items():
        if value is None:
            continue
        existing = merged.get(key)
        if isinstance(existing, Mapping) and isinstance(value, Mapping):
            merged[key] = _merge_nested(existing, value)
        else:
            merged[key] = value
    return merged


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

            CREATE TABLE IF NOT EXISTS paper_external_ids (
                id_type TEXT NOT NULL,
                id_value TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                PRIMARY KEY (id_type, id_value)
            );
            CREATE INDEX IF NOT EXISTS idx_external_ids_paper ON paper_external_ids (paper_id);

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
            CREATE INDEX IF NOT EXISTS idx_observations_source_paper_fetched
                ON source_observations (source, paper_id, fetched_at);

            CREATE TABLE IF NOT EXISTS github_repository_links (
                paper_id TEXT PRIMARY KEY REFERENCES papers(paper_id),
                arxiv_id TEXT NOT NULL,
                github_url TEXT NOT NULL,
                discovered_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_github_links_arxiv
                ON github_repository_links (arxiv_id);

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
                sort_key REAL NOT NULL DEFAULT 0,
                published_at TEXT,
                PRIMARY KEY (pool, paper_id)
            );

            CREATE TABLE IF NOT EXISTS author_index (
                author_key TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                published_at TEXT NOT NULL,
                PRIMARY KEY (author_key, paper_id)
            );
            CREATE INDEX IF NOT EXISTS idx_author_index_order
                ON author_index(author_key, published_at DESC, paper_id DESC);

            CREATE TABLE IF NOT EXISTS venue_index (
                venue_key TEXT NOT NULL,
                paper_id TEXT NOT NULL REFERENCES papers(paper_id),
                published_at TEXT NOT NULL,
                PRIMARY KEY (venue_key, paper_id)
            );
            CREATE INDEX IF NOT EXISTS idx_venue_index_order
                ON venue_index(venue_key, published_at DESC, paper_id DESC);

            CREATE TABLE IF NOT EXISTS schema_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS dataset_imports (
                dataset_key TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                source_path TEXT NOT NULL,
                source_size INTEGER NOT NULL,
                source_mtime_ns INTEGER NOT NULL,
                byte_offset INTEGER NOT NULL DEFAULT 0,
                line_number INTEGER NOT NULL DEFAULT 0,
                processed_count INTEGER NOT NULL DEFAULT 0,
                imported_count INTEGER NOT NULL DEFAULT 0,
                duplicate_count INTEGER NOT NULL DEFAULT 0,
                rejected_count INTEGER NOT NULL DEFAULT 0,
                unmatched_count INTEGER NOT NULL DEFAULT 0,
                status TEXT NOT NULL,
                started_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                completed_at TEXT,
                error TEXT
            );

            CREATE TABLE IF NOT EXISTS dataset_rejections (
                dataset_key TEXT NOT NULL REFERENCES dataset_imports(dataset_key),
                line_number INTEGER NOT NULL,
                byte_offset INTEGER NOT NULL,
                error TEXT NOT NULL,
                payload_excerpt TEXT,
                created_at TEXT NOT NULL,
                PRIMARY KEY (dataset_key, line_number)
            );
            """
        )
        columns = {row["name"] for row in self._connection.execute("PRAGMA table_info(dataset_imports)")}
        if "run_token" not in columns:
            self._connection.execute("ALTER TABLE dataset_imports ADD COLUMN run_token TEXT")
        if "lease_expires_at" not in columns:
            self._connection.execute("ALTER TABLE dataset_imports ADD COLUMN lease_expires_at TEXT")
        candidate_columns = {
            row["name"] for row in self._connection.execute("PRAGMA table_info(candidate_index)")
        }
        if "sort_key" not in candidate_columns:
            self._connection.execute(
                "ALTER TABLE candidate_index ADD COLUMN sort_key REAL NOT NULL DEFAULT 0"
            )
        if "published_at" not in candidate_columns:
            self._connection.execute("ALTER TABLE candidate_index ADD COLUMN published_at TEXT")
        self._connection.execute(
            """CREATE INDEX IF NOT EXISTS idx_candidate_index_order
               ON candidate_index(pool, sort_key DESC, published_at DESC, paper_id DESC)"""
        )
        identity_marker = self._connection.execute(
            "SELECT 1 FROM schema_meta WHERE key = 'external_identity_index_v1'"
        ).fetchone()
        if identity_marker is None:
            self._connection.execute(
                """INSERT OR IGNORE INTO paper_external_ids(id_type, id_value, paper_id)
                   SELECT ids.key, CAST(ids.value AS TEXT), papers.paper_id
                   FROM papers, json_each(papers.external_ids_json) AS ids
                   WHERE ids.value IS NOT NULL AND CAST(ids.value AS TEXT) != ''"""
            )
            self._connection.execute(
                "INSERT INTO schema_meta(key, value, updated_at) VALUES ('external_identity_index_v1', 'complete', ?)",
                (utc_now().isoformat(),),
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
                "SELECT paper_id FROM paper_external_ids WHERE id_type = ? AND id_value = ?",
                (key, value),
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
        allow_create: bool = True,
    ) -> str | None:
        existing_ids = self.find_by_external_ids(paper.external_ids)
        target_id = paper.paper_id
        if len(existing_ids) == 1:
            target_id = next(iter(existing_ids))
        elif len(existing_ids) > 1:
            self.queue_match(source, external_id, None, 1.0, "conflicting_exact_identity", raw_payload)
            return paper.paper_id
        elif not existing_ids:
            fuzzy = (
                self.find_fuzzy_candidates(
                    paper.title,
                    paper.authors[0] if paper.authors else "",
                    limit=1,
                )
                if not paper.external_ids
                else []
            )
            if fuzzy and fuzzy[0][1] >= 0.65:
                self.queue_match(source, external_id, fuzzy[0][0], fuzzy[0][1], "fuzzy_candidate_requires_review", raw_payload)
            if not allow_create:
                if not fuzzy or fuzzy[0][1] < 0.65:
                    self.queue_match(
                        source,
                        external_id,
                        None,
                        0.0,
                        "enrichment_identity_not_found",
                        raw_payload,
                    )
                return None
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
            merged = self._merge(
                current,
                paper,
                target_id,
                preserve_canonical=source != "arxiv",
            )
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
            connection.executemany(
                """INSERT INTO paper_external_ids(id_type, id_value, paper_id)
                   VALUES (?, ?, ?)
                   ON CONFLICT(id_type, id_value) DO UPDATE SET paper_id=excluded.paper_id""",
                ((key, value, merged.paper_id) for key, value in merged.external_ids.items()),
            )
            github_url = merged.metadata.get("github_url") or merged.signals.get("github", {}).get("url")
            arxiv_id = merged.external_ids.get("arxiv_id")
            if github_url and arxiv_id:
                connection.execute(
                    """INSERT INTO github_repository_links(
                           paper_id, arxiv_id, github_url, discovered_at
                       ) VALUES (?, ?, ?, ?)
                       ON CONFLICT(paper_id) DO UPDATE SET
                           arxiv_id=excluded.arxiv_id,
                           github_url=excluded.github_url,
                           discovered_at=excluded.discovered_at""",
                    (merged.paper_id, arxiv_id, str(github_url), fetched_at.isoformat()),
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

    def _merge(
        self,
        current: PaperRecord,
        incoming: PaperRecord,
        target_id: str,
        *,
        preserve_canonical: bool,
    ) -> PaperRecord:
        external_ids = dict(current.external_ids)
        external_ids.update({key: value for key, value in incoming.external_ids.items() if value})
        signals = {key: dict(value) for key, value in current.signals.items()}
        for key, value in incoming.signals.items():
            signals.setdefault(key, {}).update({field: val for field, val in value.items() if val is not None})
        metadata = dict(current.metadata)
        metadata.update({key: value for key, value in incoming.metadata.items() if value is not None})
        title = current.title if preserve_canonical or current.title.strip() else incoming.title
        abstract = current.abstract or incoming.abstract if preserve_canonical else incoming.abstract or current.abstract
        authors = current.authors or incoming.authors
        published_at = current.published_at if preserve_canonical else min(current.published_at, incoming.published_at)
        updated_at = (
            current.updated_at
            if preserve_canonical
            else max(filter(None, (current.updated_at, incoming.updated_at)), default=None)
        )
        subjects = (
            current.subjects
            if preserve_canonical
            else tuple(dict.fromkeys((*current.subjects, *incoming.subjects)))
        )
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
        wanted_authors = tuple(sorted({str(item).strip().lower() for item in authors if str(item).strip()}))
        wanted_subjects = tuple(sorted({str(item).strip().lower() for item in subjects if str(item).strip()}))
        wanted_venues = tuple(sorted({str(item).strip().lower() for item in venues if str(item).strip()}))
        match_queries: list[str] = []
        params: list[Any] = []
        if wanted_authors:
            placeholders = ",".join("?" for _ in wanted_authors)
            match_queries.append(f"SELECT paper_id FROM author_index WHERE author_key IN ({placeholders})")
            params.extend(wanted_authors)
        if wanted_subjects:
            placeholders = ",".join("?" for _ in wanted_subjects)
            match_queries.append(f"SELECT paper_id FROM channel_index WHERE channel_key IN ({placeholders})")
            params.extend(f"subject:{subject}" for subject in wanted_subjects)
        if wanted_venues:
            placeholders = ",".join("?" for _ in wanted_venues)
            match_queries.append(f"SELECT paper_id FROM venue_index WHERE venue_key IN ({placeholders})")
            params.extend(wanted_venues)
        if not match_queries:
            return [], None
        clauses = ["papers.admitted = 1", "papers.withdrawn = 0"]
        direct_index: str | None = None
        direct_values: tuple[str, ...] = ()
        if wanted_authors and not wanted_subjects and not wanted_venues:
            direct_index = "author_index"
            direct_values = wanted_authors
        elif wanted_subjects and not wanted_authors and not wanted_venues:
            direct_index = "channel_index"
            direct_values = tuple(f"subject:{subject}" for subject in wanted_subjects)
        elif wanted_venues and not wanted_authors and not wanted_subjects:
            direct_index = "venue_index"
            direct_values = wanted_venues
        if direct_index:
            placeholders = ",".join("?" for _ in direct_values)
            params = list(direct_values)
            direct_date_column = "matched.sort_key" if direct_index == "channel_index" else "matched.published_at"
            if cursor:
                clauses.append(
                    f"({direct_date_column} < ? OR ({direct_date_column} = ? AND matched.paper_id < ?))"
                )
                params.extend((cursor[0], cursor[0], cursor[1]))
            bounded_limit = max(1, min(limit, 100))
            params.append(bounded_limit + 1)
            rows = self._connection.execute(
                f"""SELECT papers.* FROM {direct_index} AS matched
                    JOIN papers ON papers.paper_id = matched.paper_id
                    WHERE matched.{('author_key' if direct_index == 'author_index' else 'venue_key' if direct_index == 'venue_index' else 'channel_key')} IN ({placeholders})
                      AND {' AND '.join(clauses)}
                    ORDER BY {direct_date_column} DESC, matched.paper_id DESC LIMIT ?""",
                params,
            ).fetchall()
        else:
            matches = " UNION ".join(match_queries)
            if cursor:
                clauses.append(
                    "(papers.published_at < ? OR (papers.published_at = ? AND papers.paper_id < ?))"
                )
                params.extend((cursor[0], cursor[0], cursor[1]))
            bounded_limit = max(1, min(limit, 100))
            params.append(bounded_limit + 1)
            rows = self._connection.execute(
                f"SELECT papers.* FROM papers JOIN ({matches}) AS matched "
                f"ON matched.paper_id = papers.paper_id WHERE {' AND '.join(clauses)} "
                "ORDER BY papers.published_at DESC, papers.paper_id DESC LIMIT ?",
                params,
            ).fetchall()
        bounded = [self._row_to_paper(row) for row in rows[:bounded_limit]]
        next_cursor = None
        if len(rows) > len(bounded) and bounded:
            next_cursor = (bounded[-1].published_at.isoformat(), bounded[-1].paper_id)
        return bounded, next_cursor

    def refresh_indexes(self, generated_at: datetime | None = None) -> None:
        generated_at = generated_at or utc_now()
        generated = generated_at.isoformat()
        with self.transaction() as connection:
            connection.execute("DELETE FROM latest_index")
            connection.execute(
                """INSERT INTO latest_index(paper_id, published_at, generated_at)
                   SELECT paper_id, published_at, ? FROM papers
                   WHERE admitted = 1 AND withdrawn = 0
                     AND EXISTS (
                       SELECT 1 FROM json_each(papers.discovery_sources_json)
                       WHERE value IN ('arxiv', 'huggingface')
                     )""",
                (generated,),
            )
        with self.transaction() as connection:
            connection.execute("DELETE FROM channel_index")
            connection.execute("DELETE FROM author_index")
            connection.execute("DELETE FROM venue_index")
            connection.execute(
                """INSERT OR REPLACE INTO channel_index(channel_key, paper_id, sort_key, generated_at)
                   SELECT 'subject:' || lower(subjects.value), papers.paper_id, papers.published_at, ?
                   FROM papers JOIN json_each(papers.subjects_json) AS subjects
                   WHERE papers.admitted = 1 AND papers.withdrawn = 0""",
                (generated,),
            )
            connection.execute(
                """INSERT OR REPLACE INTO author_index(author_key, paper_id, published_at)
                   SELECT lower(authors.value), papers.paper_id, papers.published_at
                   FROM papers JOIN json_each(papers.authors_json) AS authors
                   WHERE papers.admitted = 1 AND papers.withdrawn = 0
                     AND trim(CAST(authors.value AS TEXT)) != ''"""
            )
            connection.execute(
                """INSERT OR REPLACE INTO venue_index(venue_key, paper_id, published_at)
                   SELECT lower(json_extract(metadata_json, '$.venue_name')), paper_id, published_at
                   FROM papers
                   WHERE admitted = 1 AND withdrawn = 0
                     AND json_extract(metadata_json, '$.venue_name') IS NOT NULL"""
            )
        with self.transaction() as connection:
            connection.execute("DELETE FROM candidate_index")
            connection.execute(
                """INSERT INTO candidate_index(pool, paper_id, generated_at, sort_key, published_at)
                   SELECT 'all', paper_id, ?, 0, published_at FROM papers
                   WHERE admitted = 1 AND withdrawn = 0""",
                (generated,),
            )
            boundaries = (
                ("0-1y", generated_at - timedelta(days=365.25), generated_at),
                ("1-3y", generated_at - timedelta(days=365.25 * 3), generated_at - timedelta(days=365.25)),
                ("3-5y", generated_at - timedelta(days=365.25 * 5), generated_at - timedelta(days=365.25 * 3)),
                ("5y+", None, generated_at - timedelta(days=365.25 * 5)),
            )
            quality_sort = """CASE
                WHEN json_extract(signals_json, '$.openalex.citation_count_outlier') = 1
                THEN 0
                ELSE COALESCE(
                    json_extract(signals_json, '$.openalex.citation_count'),
                    json_extract(signals_json, '$.semantic_scholar.citation_count'),
                    0
                )
            END"""
            for bucket, lower, upper in boundaries:
                clauses = ["admitted = 1", "withdrawn = 0", "published_at < ?"]
                date_params: list[Any] = [upper.isoformat()]
                if lower is not None:
                    clauses.append("published_at >= ?")
                    date_params.append(lower.isoformat())
                where = " AND ".join(clauses)
                quality_where = (
                    f"{where} AND "
                    "(json_extract(signals_json, '$.openalex.citation_count_outlier') IS NULL "
                    "OR json_extract(signals_json, '$.openalex.citation_count_outlier') != 1)"
                )
                connection.execute(
                    f"""INSERT INTO candidate_index(pool, paper_id, generated_at, sort_key, published_at)
                        SELECT ?, paper_id, ?,
                               {quality_sort},
                               published_at
                        FROM papers WHERE {quality_where}
                        ORDER BY {quality_sort} DESC,
                                 published_at DESC, paper_id DESC LIMIT 5000""",
                    (f"quality:{bucket}", generated, *date_params),
                )
                connection.execute(
                    f"""INSERT INTO candidate_index(pool, paper_id, generated_at, sort_key, published_at)
                        SELECT ?, paper_id, ?,
                               COALESCE(json_extract(signals_json, '$.huggingface.heat'), 0),
                               published_at
                        FROM papers WHERE {where}
                        ORDER BY COALESCE(json_extract(signals_json, '$.huggingface.heat'), 0) DESC,
                                 published_at DESC, paper_id DESC LIMIT 5000""",
                    (f"trending:{bucket}", generated, *date_params),
                )

    def all_candidates(self) -> list[PaperRecord]:
        rows = self._connection.execute(
            "SELECT * FROM papers WHERE admitted = 1 AND withdrawn = 0 ORDER BY published_at DESC, paper_id DESC"
        ).fetchall()
        return [self._row_to_paper(row) for row in rows]

    def recommendation_candidates(
        self,
        *,
        read_ids: Iterable[str] = (),
        per_pool_limit: int = 500,
        as_of: datetime | None = None,
    ) -> list[PaperRecord]:
        as_of = as_of or utc_now()
        per_pool_limit = max(1, min(int(per_pool_limit), 5000))
        read = set(list(read_ids)[:5000])
        has_materialized_pools = self._connection.execute(
            "SELECT 1 FROM candidate_index WHERE pool LIKE 'quality:%' LIMIT 1"
        ).fetchone()
        if has_materialized_pools is not None:
            rows_by_id: dict[str, sqlite3.Row] = {}
            for bucket in ("0-1y", "1-3y", "3-5y", "5y+"):
                for pool in ("quality", "trending"):
                    rows = self._connection.execute(
                        """SELECT papers.* FROM candidate_index
                           JOIN papers ON papers.paper_id = candidate_index.paper_id
                           WHERE candidate_index.pool = ?
                           ORDER BY candidate_index.sort_key DESC,
                                    candidate_index.published_at DESC,
                                    candidate_index.paper_id DESC LIMIT ?""",
                        (f"{pool}:{bucket}", per_pool_limit),
                    ).fetchall()
                    for row in rows:
                        if row["paper_id"] not in read:
                            rows_by_id[row["paper_id"]] = row
            return [paper_from_row(row, []) for row in rows_by_id.values()]
        boundaries = (
            (as_of - timedelta(days=365.25), as_of),
            (as_of - timedelta(days=365.25 * 3), as_of - timedelta(days=365.25)),
            (as_of - timedelta(days=365.25 * 5), as_of - timedelta(days=365.25 * 3)),
            (None, as_of - timedelta(days=365.25 * 5)),
        )
        rows_by_id: dict[str, sqlite3.Row] = {}
        orders = (
            """CASE
                WHEN json_extract(signals_json, '$.openalex.citation_count_outlier') = 1
                THEN -1
                ELSE COALESCE(
                    json_extract(signals_json, '$.openalex.citation_count'),
                    json_extract(signals_json, '$.semantic_scholar.citation_count'),
                    -1
                )
            END DESC, published_at DESC, paper_id DESC""",
            "COALESCE(json_extract(signals_json, '$.huggingface.heat'), -1) DESC, published_at DESC, paper_id DESC",
        )
        for lower, upper in boundaries:
            clauses = ["admitted = 1", "withdrawn = 0", "published_at < ?"]
            params: list[Any] = [upper.isoformat()]
            if lower is not None:
                clauses.append("published_at >= ?")
                params.append(lower.isoformat())
            for order_index, order in enumerate(orders):
                order_clauses = clauses
                if order_index == 0:
                    order_clauses = [
                        *clauses,
                        "(json_extract(signals_json, '$.openalex.citation_count_outlier') IS NULL "
                        "OR json_extract(signals_json, '$.openalex.citation_count_outlier') != 1)",
                    ]
                query_params = [*params, per_pool_limit]
                rows = self._connection.execute(
                    f"SELECT * FROM papers WHERE {' AND '.join(order_clauses)} ORDER BY {order} LIMIT ?",
                    query_params,
                ).fetchall()
                for row in rows:
                    if row["paper_id"] not in read:
                        rows_by_id[row["paper_id"]] = row
        return [paper_from_row(row, []) for row in rows_by_id.values()]

    def semantic_scholar_candidates(
        self,
        *,
        limit: int = 500,
        stale_before: datetime | None = None,
    ) -> list[str]:
        bounded_limit = max(1, min(int(limit), 5000))
        stale_value = stale_before.isoformat() if stale_before else None
        selected: dict[str, None] = {}
        quality_limit = max(1, (bounded_limit + 1) // 2)
        queries = (
            ("""SELECT json_extract(papers.external_ids_json, '$.arxiv_id') AS arxiv_id
               FROM candidate_index
               JOIN papers ON papers.paper_id = candidate_index.paper_id
               LEFT JOIN source_observations AS observation
                 ON observation.paper_id = papers.paper_id
                AND observation.source = 'semantic_scholar'
               WHERE candidate_index.pool LIKE 'quality:%'
                 AND json_extract(papers.external_ids_json, '$.arxiv_id') IS NOT NULL
                 AND (? IS NULL OR observation.fetched_at IS NULL OR observation.fetched_at < ?)
               ORDER BY candidate_index.sort_key DESC,
                        candidate_index.published_at DESC,
                        candidate_index.paper_id DESC
               LIMIT ?""", quality_limit),
            ("""SELECT json_extract(papers.external_ids_json, '$.arxiv_id') AS arxiv_id
               FROM latest_index
               JOIN papers ON papers.paper_id = latest_index.paper_id
               LEFT JOIN source_observations AS observation
                 ON observation.paper_id = papers.paper_id
                AND observation.source = 'semantic_scholar'
               WHERE json_extract(papers.external_ids_json, '$.arxiv_id') IS NOT NULL
                 AND (? IS NULL OR observation.fetched_at IS NULL OR observation.fetched_at < ?)
               ORDER BY latest_index.published_at DESC, latest_index.paper_id DESC
               LIMIT ?""", bounded_limit),
            ("""SELECT json_extract(papers.external_ids_json, '$.arxiv_id') AS arxiv_id
               FROM papers
               LEFT JOIN source_observations AS observation
                 ON observation.paper_id = papers.paper_id
                AND observation.source = 'semantic_scholar'
               WHERE papers.admitted = 1 AND papers.withdrawn = 0
                 AND json_extract(papers.external_ids_json, '$.arxiv_id') IS NOT NULL
                 AND (? IS NULL OR observation.fetched_at IS NULL OR observation.fetched_at < ?)
               ORDER BY papers.published_at DESC, papers.paper_id DESC
               LIMIT ?""", bounded_limit),
        )
        for query, query_limit in queries:
            rows = self._connection.execute(
                query,
                (stale_value, stale_value, query_limit),
            ).fetchall()
            for row in rows:
                arxiv_id = str(row["arxiv_id"] or "").strip()
                if arxiv_id:
                    selected.setdefault(arxiv_id, None)
                if len(selected) >= bounded_limit:
                    return list(selected)
        return list(selected)

    def github_candidates(
        self,
        *,
        limit: int = 50,
        stale_before: datetime | None = None,
    ) -> list[dict[str, str]]:
        bounded_limit = max(1, min(int(limit), 500))
        stale_value = stale_before.isoformat() if stale_before else None
        rows = self._connection.execute(
            """SELECT links.paper_id, links.arxiv_id, links.github_url
               FROM github_repository_links AS links
               LEFT JOIN source_observations AS observation
                 ON observation.paper_id = links.paper_id
                AND observation.source = 'github'
               WHERE (? IS NULL OR observation.fetched_at IS NULL OR observation.fetched_at < ?)
               ORDER BY links.discovered_at DESC, links.paper_id DESC
               LIMIT ?""",
            (stale_value, stale_value, bounded_limit),
        ).fetchall()
        return [
            {
                "paper_id": str(row["paper_id"]),
                "arxiv_id": str(row["arxiv_id"]),
                "github_url": str(row["github_url"]),
            }
            for row in rows
        ]

    def start_dataset_import(
        self,
        *,
        dataset_key: str,
        source: str,
        source_path: str,
        source_size: int,
        source_mtime_ns: int,
        started_at: datetime,
        run_token: str,
        lease_seconds: int = 120,
    ) -> dict[str, Any]:
        existing = self.get_dataset_import(dataset_key)
        lease_expires_at = started_at + timedelta(seconds=max(30, lease_seconds))
        if existing is not None:
            unchanged = (
                existing["source_path"] == source_path
                and int(existing["source_size"]) == source_size
                and int(existing["source_mtime_ns"]) == source_mtime_ns
            )
            if not unchanged:
                raise ValueError(f"dataset source changed after checkpoint: {dataset_key}")
            if existing["status"] == "completed":
                return existing
            active_lease = parse_datetime(existing.get("lease_expires_at"))
            if (
                existing.get("run_token")
                and existing["run_token"] != run_token
                and active_lease is not None
                and active_lease > started_at
            ):
                raise RuntimeError(f"dataset import already running: {dataset_key}")
            self._connection.execute(
                """UPDATE dataset_imports SET status = 'running', error = NULL,
                   run_token = ?, lease_expires_at = ?, updated_at = ? WHERE dataset_key = ?""",
                (run_token, lease_expires_at.isoformat(), started_at.isoformat(), dataset_key),
            )
            self._connection.commit()
            return self.get_dataset_import(dataset_key) or existing
        self._connection.execute(
            """INSERT INTO dataset_imports(
                   dataset_key, source, source_path, source_size, source_mtime_ns,
                   status, started_at, updated_at, run_token, lease_expires_at
               ) VALUES (?, ?, ?, ?, ?, 'running', ?, ?, ?, ?)""",
            (
                dataset_key,
                source,
                source_path,
                source_size,
                source_mtime_ns,
                started_at.isoformat(),
                started_at.isoformat(),
                run_token,
                lease_expires_at.isoformat(),
            ),
        )
        self._connection.commit()
        return self.get_dataset_import(dataset_key) or {}

    def get_dataset_import(self, dataset_key: str) -> dict[str, Any] | None:
        row = self._connection.execute(
            "SELECT * FROM dataset_imports WHERE dataset_key = ?", (dataset_key,)
        ).fetchone()
        return dict(row) if row else None

    def list_dataset_imports(self, prefix: str = "") -> list[dict[str, Any]]:
        if prefix:
            rows = self._connection.execute(
                "SELECT * FROM dataset_imports WHERE dataset_key LIKE ? ORDER BY dataset_key",
                (prefix + "%",),
            ).fetchall()
        else:
            rows = self._connection.execute("SELECT * FROM dataset_imports ORDER BY dataset_key").fetchall()
        return [dict(row) for row in rows]

    def apply_dataset_paper_batch(
        self,
        *,
        dataset_key: str,
        records: list[Mapping[str, Any]],
        rejections: list[Mapping[str, Any]],
        byte_offset: int,
        line_number: int,
        fetched_at: datetime,
        run_token: str,
        lease_seconds: int = 120,
    ) -> dict[str, int]:
        paper_ids = [str(item["paper"].paper_id) for item in records]
        existing_ids: set[str] = set()
        for start in range(0, len(paper_ids), 500):
            chunk = paper_ids[start : start + 500]
            if not chunk:
                continue
            placeholders = ",".join("?" for _ in chunk)
            rows = self._connection.execute(
                f"SELECT paper_id FROM papers WHERE paper_id IN ({placeholders})", chunk
            ).fetchall()
            existing_ids.update(row["paper_id"] for row in rows)
        unique_ids = set(paper_ids)
        imported = len(unique_ids - existing_ids)
        duplicates = len(records) - imported
        at = fetched_at.isoformat()
        with self.transaction() as connection:
            connection.executemany(
                """INSERT INTO papers(
                       paper_id, title, abstract, authors_json, published_at, updated_at,
                       subjects_json, external_ids_json, discovery_sources_json, signals_json,
                       metadata_json, admitted, admission_reason, withdrawn, created_at,
                       last_seen_at, schema_version
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(paper_id) DO UPDATE SET
                       title=excluded.title, abstract=excluded.abstract,
                       authors_json=excluded.authors_json, published_at=excluded.published_at,
                       updated_at=excluded.updated_at, subjects_json=excluded.subjects_json,
                       external_ids_json=json_patch(papers.external_ids_json, excluded.external_ids_json),
                       signals_json=json_patch(papers.signals_json, excluded.signals_json),
                       metadata_json=json_patch(papers.metadata_json, excluded.metadata_json),
                       admitted=excluded.admitted, admission_reason=excluded.admission_reason,
                       withdrawn=excluded.withdrawn, last_seen_at=excluded.last_seen_at,
                       schema_version=excluded.schema_version""",
                (paper_values(item["paper"], fetched_at, fetched_at) for item in records),
            )
            identity_rows = [
                (key, value, item["paper"].paper_id)
                for item in records
                for key, value in item["paper"].external_ids.items()
            ]
            connection.executemany(
                """INSERT INTO paper_external_ids(id_type, id_value, paper_id)
                   VALUES (?, ?, ?)
                   ON CONFLICT(id_type, id_value) DO UPDATE SET paper_id=excluded.paper_id""",
                identity_rows,
            )
            connection.executemany(
                """INSERT INTO source_observations(
                       source, external_id, paper_id, payload_json, source_updated_at, fetched_at, etag
                   ) VALUES (?, ?, ?, ?, ?, ?, NULL)
                   ON CONFLICT(source, external_id) DO UPDATE SET
                       paper_id=excluded.paper_id, payload_json=excluded.payload_json,
                       source_updated_at=excluded.source_updated_at, fetched_at=excluded.fetched_at""",
                (
                    (
                        item["source"],
                        item["external_id"],
                        item["paper"].paper_id,
                        _json(item["raw_payload"]),
                        item["source_updated_at"].isoformat() if item.get("source_updated_at") else None,
                        at,
                    )
                    for item in records
                ),
            )
            provenance_rows = [
                (
                    item["paper"].paper_id,
                    field_name,
                    item["source"],
                    at,
                    item["source_updated_at"].isoformat() if item.get("source_updated_at") else None,
                    _json(evidence),
                )
                for item in records
                for field_name, evidence in item["provenance"].items()
            ]
            connection.executemany(
                """INSERT INTO provenance(
                       paper_id, field_name, source, fetched_at, source_updated_at, evidence_json
                   ) VALUES (?, ?, ?, ?, ?, ?)
                   ON CONFLICT(paper_id, field_name, source) DO UPDATE SET
                       fetched_at=excluded.fetched_at,
                       source_updated_at=excluded.source_updated_at,
                       evidence_json=excluded.evidence_json""",
                provenance_rows,
            )
            self._insert_dataset_rejections(connection, dataset_key, rejections, fetched_at)
            updated = connection.execute(
                """UPDATE dataset_imports SET
                       byte_offset = ?, line_number = ?,
                       processed_count = processed_count + ?,
                       imported_count = imported_count + ?,
                       duplicate_count = duplicate_count + ?,
                       rejected_count = rejected_count + ?,
                       status = 'running', updated_at = ?, error = NULL,
                       lease_expires_at = ?
                   WHERE dataset_key = ? AND run_token = ?""",
                (
                    byte_offset,
                    line_number,
                    len(records) + len(rejections),
                    imported,
                    duplicates,
                    len(rejections),
                    at,
                    (fetched_at + timedelta(seconds=max(30, lease_seconds))).isoformat(),
                    dataset_key,
                    run_token,
                ),
            )
            if updated.rowcount != 1:
                raise RuntimeError(f"dataset import lease lost: {dataset_key}")
        return {"imported": imported, "duplicates": duplicates, "rejected": len(rejections)}

    def apply_dataset_enrichment_batch(
        self,
        *,
        dataset_key: str,
        records: list[Mapping[str, Any]],
        rejections: list[Mapping[str, Any]],
        byte_offset: int,
        line_number: int,
        fetched_at: datetime,
        run_token: str,
        lease_seconds: int = 120,
    ) -> dict[str, int]:
        lookup_values = tuple(dict.fromkeys(str(item["lookup_value"]) for item in records))
        identities: dict[str, str] = {}
        for start in range(0, len(lookup_values), 500):
            chunk = lookup_values[start : start + 500]
            if not chunk:
                continue
            placeholders = ",".join("?" for _ in chunk)
            rows = self._connection.execute(
                f"SELECT id_value, paper_id FROM paper_external_ids "
                f"WHERE id_type = 'arxiv_id' AND id_value IN ({placeholders})",
                chunk,
            ).fetchall()
            identities.update({row["id_value"]: row["paper_id"] for row in rows})
        matched_records = [(item, identities.get(str(item["lookup_value"]))) for item in records]
        matched_records = [(item, paper_id) for item, paper_id in matched_records if paper_id is not None]
        paper_ids = tuple(dict.fromkeys(str(paper_id) for _, paper_id in matched_records))
        current_rows: dict[str, sqlite3.Row] = {}
        for start in range(0, len(paper_ids), 500):
            chunk = paper_ids[start : start + 500]
            if not chunk:
                continue
            placeholders = ",".join("?" for _ in chunk)
            rows = self._connection.execute(
                f"SELECT paper_id, external_ids_json, signals_json, metadata_json FROM papers "
                f"WHERE paper_id IN ({placeholders})",
                chunk,
            ).fetchall()
            current_rows.update({row["paper_id"]: row for row in rows})
        at = fetched_at.isoformat()
        updates: list[tuple[str, str, str, str, str]] = []
        identity_rows: list[tuple[str, str, str]] = []
        observation_rows: list[tuple[Any, ...]] = []
        provenance_rows: list[tuple[Any, ...]] = []
        for item, paper_id in matched_records:
            current = current_rows[str(paper_id)]
            external_ids = _merge_nested(_load(current["external_ids_json"], {}), item.get("external_ids") or {})
            signals = _merge_nested(_load(current["signals_json"], {}), item.get("signals") or {})
            metadata = _merge_nested(_load(current["metadata_json"], {}), item.get("metadata") or {})
            updates.append((_json(external_ids), _json(signals), _json(metadata), at, str(paper_id)))
            identity_rows.extend((key, value, str(paper_id)) for key, value in (item.get("external_ids") or {}).items())
            observation_rows.append(
                (
                    item["source"],
                    item["external_id"],
                    str(paper_id),
                    _json(item["raw_payload"]),
                    at,
                )
            )
            provenance_rows.extend(
                (
                    str(paper_id),
                    field_name,
                    item["source"],
                    at,
                    _json(evidence),
                )
                for field_name, evidence in item["provenance"].items()
            )
        unmatched = len(records) - len(matched_records)
        with self.transaction() as connection:
            connection.executemany(
                """UPDATE papers SET external_ids_json = ?, signals_json = ?, metadata_json = ?,
                   last_seen_at = ? WHERE paper_id = ?""",
                updates,
            )
            connection.executemany(
                """INSERT INTO paper_external_ids(id_type, id_value, paper_id)
                   VALUES (?, ?, ?)
                   ON CONFLICT(id_type, id_value) DO UPDATE SET paper_id=excluded.paper_id""",
                identity_rows,
            )
            connection.executemany(
                """INSERT INTO source_observations(
                       source, external_id, paper_id, payload_json, source_updated_at, fetched_at, etag
                   ) VALUES (?, ?, ?, ?, NULL, ?, NULL)
                   ON CONFLICT(source, external_id) DO UPDATE SET
                       paper_id=excluded.paper_id, payload_json=excluded.payload_json,
                       fetched_at=excluded.fetched_at""",
                observation_rows,
            )
            connection.executemany(
                """INSERT INTO provenance(
                       paper_id, field_name, source, fetched_at, source_updated_at, evidence_json
                   ) VALUES (?, ?, ?, ?, NULL, ?)
                   ON CONFLICT(paper_id, field_name, source) DO UPDATE SET
                       fetched_at=excluded.fetched_at, evidence_json=excluded.evidence_json""",
                provenance_rows,
            )
            self._insert_dataset_rejections(connection, dataset_key, rejections, fetched_at)
            updated = connection.execute(
                """UPDATE dataset_imports SET
                       byte_offset = ?, line_number = ?,
                       processed_count = processed_count + ?,
                       imported_count = imported_count + ?,
                       rejected_count = rejected_count + ?,
                       unmatched_count = unmatched_count + ?,
                       status = 'running', updated_at = ?, error = NULL,
                       lease_expires_at = ?
                   WHERE dataset_key = ? AND run_token = ?""",
                (
                    byte_offset,
                    line_number,
                    len(records) + len(rejections),
                    len(matched_records),
                    len(rejections),
                    unmatched,
                    at,
                    (fetched_at + timedelta(seconds=max(30, lease_seconds))).isoformat(),
                    dataset_key,
                    run_token,
                ),
            )
            if updated.rowcount != 1:
                raise RuntimeError(f"dataset import lease lost: {dataset_key}")
        return {"matched": len(matched_records), "unmatched": unmatched, "rejected": len(rejections)}

    def _insert_dataset_rejections(
        self,
        connection: sqlite3.Connection,
        dataset_key: str,
        rejections: list[Mapping[str, Any]],
        created_at: datetime,
    ) -> None:
        connection.executemany(
            """INSERT OR REPLACE INTO dataset_rejections(
                   dataset_key, line_number, byte_offset, error, payload_excerpt, created_at
               ) VALUES (?, ?, ?, ?, ?, ?)""",
            (
                (
                    dataset_key,
                    int(item["line_number"]),
                    int(item["byte_offset"]),
                    str(item["error"]),
                    str(item.get("payload_excerpt") or "")[:1000],
                    created_at.isoformat(),
                )
                for item in rejections
            ),
        )

    def complete_dataset_import(
        self,
        dataset_key: str,
        completed_at: datetime,
        *,
        run_token: str,
    ) -> dict[str, Any]:
        updated = self._connection.execute(
            """UPDATE dataset_imports SET status = 'completed', completed_at = ?,
               updated_at = ?, error = NULL, run_token = NULL, lease_expires_at = NULL
               WHERE dataset_key = ? AND run_token = ?""",
            (completed_at.isoformat(), completed_at.isoformat(), dataset_key, run_token),
        )
        if updated.rowcount != 1:
            self._connection.rollback()
            raise RuntimeError(f"dataset import lease lost: {dataset_key}")
        self._connection.commit()
        return self.get_dataset_import(dataset_key) or {}

    def pause_dataset_import(self, dataset_key: str, paused_at: datetime, *, run_token: str) -> dict[str, Any]:
        updated = self._connection.execute(
            """UPDATE dataset_imports SET run_token = NULL, lease_expires_at = NULL,
               updated_at = ? WHERE dataset_key = ? AND run_token = ?""",
            (paused_at.isoformat(), dataset_key, run_token),
        )
        if updated.rowcount != 1:
            self._connection.rollback()
            raise RuntimeError(f"dataset import lease lost: {dataset_key}")
        self._connection.commit()
        return self.get_dataset_import(dataset_key) or {}

    def fail_dataset_import(self, dataset_key: str, error: str, failed_at: datetime, *, run_token: str) -> None:
        self._connection.execute(
            """UPDATE dataset_imports SET status = 'failed', error = ?, updated_at = ?,
               run_token = NULL, lease_expires_at = NULL
               WHERE dataset_key = ? AND run_token = ?""",
            (error, failed_at.isoformat(), dataset_key, run_token),
        )
        self._connection.commit()

    def reconcile_arxiv_dataset(self, dataset_key: str, source_path: str) -> dict[str, Any]:
        state = self.get_dataset_import(dataset_key)
        if state is None:
            raise ValueError(f"unknown dataset import: {dataset_key}")
        observations = int(
            self._connection.execute(
                """SELECT COUNT(*) FROM source_observations
                   WHERE source = 'arxiv'
                     AND json_extract(payload_json, '$.source_path') = ?""",
                (source_path,),
            ).fetchone()[0]
        )
        rejected = int(
            self._connection.execute(
                "SELECT COUNT(*) FROM dataset_rejections WHERE dataset_key = ?", (dataset_key,)
            ).fetchone()[0]
        )
        processed = int(state["line_number"])
        duplicates = max(processed - observations - rejected, 0)
        self._connection.execute(
            """UPDATE dataset_imports SET processed_count = ?, imported_count = ?,
               duplicate_count = ?, rejected_count = ?, updated_at = ?
               WHERE dataset_key = ?""",
            (processed, observations, duplicates, rejected, utc_now().isoformat(), dataset_key),
        )
        self._connection.commit()
        return self.get_dataset_import(dataset_key) or {}

    def indexes_ready(self) -> bool:
        admitted = int(
            self._connection.execute(
                "SELECT COUNT(*) FROM papers WHERE admitted = 1 AND withdrawn = 0"
            ).fetchone()[0]
        )
        latest = int(self._connection.execute("SELECT COUNT(*) FROM latest_index").fetchone()[0])
        candidates = int(
            self._connection.execute(
                "SELECT COUNT(*) FROM candidate_index WHERE pool = 'all'"
            ).fetchone()[0]
        )
        recommendation_pools = int(
            self._connection.execute(
                "SELECT COUNT(*) FROM candidate_index WHERE pool LIKE 'quality:%' OR pool LIKE 'trending:%'"
            ).fetchone()[0]
        )
        author_rows = int(self._connection.execute("SELECT COUNT(*) FROM author_index").fetchone()[0])
        return admitted == latest == candidates and recommendation_pools > 0 and author_rows > 0

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
