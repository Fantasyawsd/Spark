from __future__ import annotations

import sqlite3
from dataclasses import replace
from contextlib import contextmanager
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Iterable, Iterator, Mapping

from . import PAPER_SCHEMA_VERSION
from .database_values import encode_json, load_json
from .dataset_storage import DatasetStorage
from .db_mapper import paper_from_row, paper_values
from .identity import fuzzy_identity_score, normalize_external_ids, stable_paper_id
from .identity_resolution import (
    IdentityResolutionAction,
    needs_fuzzy_lookup,
    resolve_identity,
)
from .models import PaperRecord, parse_datetime, utc_now
from .ports import IngestOutcome, IngestStatus
from .paper_record_merger import merge_paper_records
from .storage_schema import StorageSchemaManager


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
        try:
            StorageSchemaManager(self._connection).initialize(
                paper_schema_version=PAPER_SCHEMA_VERSION,
                timestamp_factory=utc_now,
            )
        except Exception:
            self._connection.close()
            raise
        self._dataset_storage = DatasetStorage(
            self._connection,
            timestamp_factory=utc_now,
        )

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

    def _row_to_paper(self, row: sqlite3.Row) -> PaperRecord:
        return self._rows_to_papers((row,))[0]

    def _rows_to_papers(self, rows: Iterable[sqlite3.Row]) -> list[PaperRecord]:
        rows = tuple(rows)
        if not rows:
            return []
        paper_ids = tuple(dict.fromkeys(row["paper_id"] for row in rows))
        placeholders = ",".join("?" for _ in paper_ids)
        provenance_by_paper: dict[str, list[sqlite3.Row]] = {paper_id: [] for paper_id in paper_ids}
        provenance_rows = self._connection.execute(
            f"SELECT * FROM provenance WHERE paper_id IN ({placeholders}) ORDER BY paper_id, field_name, source",
            paper_ids,
        ).fetchall()
        for provenance_row in provenance_rows:
            provenance_by_paper[provenance_row["paper_id"]].append(provenance_row)
        return [paper_from_row(row, provenance_by_paper[row["paper_id"]]) for row in rows]

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
            (row["paper_id"], fuzzy_identity_score(title, row["title"], author, (load_json(row["authors_json"], [""]) or [""])[0]))
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
            (source, external_id, candidate_paper_id, confidence, reason, encode_json(payload), utc_now().isoformat()),
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
    ) -> IngestOutcome:
        existing_ids = self.find_by_external_ids(paper.external_ids)
        fuzzy_candidate = None
        if needs_fuzzy_lookup(existing_ids, has_external_ids=bool(paper.external_ids)):
            fuzzy_candidates = self.find_fuzzy_candidates(
                paper.title,
                paper.authors[0] if paper.authors else "",
                limit=1,
            )
            fuzzy_candidate = fuzzy_candidates[0] if fuzzy_candidates else None
        resolution = resolve_identity(
            paper.paper_id,
            exact_match_ids=existing_ids,
            has_external_ids=bool(paper.external_ids),
            best_fuzzy_candidate=fuzzy_candidate,
            allow_create=allow_create,
        )
        if resolution.review is not None:
            self.queue_match(
                source,
                external_id,
                resolution.review.candidate_paper_id,
                resolution.review.confidence,
                resolution.review.reason,
                raw_payload,
            )
        if resolution.action is IdentityResolutionAction.CONFLICT:
            return IngestOutcome(IngestStatus.CONFLICT)
        if resolution.action is IdentityResolutionAction.UNMATCHED:
            return IngestOutcome(IngestStatus.UNMATCHED)
        target_id = resolution.target_paper_id
        if target_id is None:
            raise RuntimeError("stored identity resolution must include a target paper ID")
        current = self.get(target_id)
        if current is None:
            merged = paper if target_id == paper.paper_id else replace(
                paper,
                paper_id=target_id,
            )
            created_at = fetched_at
        else:
            merged = merge_paper_records(
                current,
                paper,
                target_id,
                preserve_canonical=source != "arxiv",
                add_discovery_source=source in {"arxiv", "huggingface"},
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
                    encode_json(raw_payload),
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
                        encode_json(evidence),
                    ),
                )
        return IngestOutcome(IngestStatus.STORED, merged.paper_id)

    def withdraw_by_external_id(
        self,
        *,
        source: str,
        external_id: str,
        raw_payload: Mapping[str, Any],
        fetched_at: datetime,
        source_updated_at: datetime | None = None,
    ) -> bool:
        normalized = normalize_external_ids({"arxiv_id": external_id}).get("arxiv_id")
        if not normalized:
            return False
        row = self._connection.execute(
            "SELECT paper_id FROM paper_external_ids WHERE id_type = 'arxiv_id' AND id_value = ?",
            (normalized,),
        ).fetchone()
        if row is None:
            return False
        paper_id = str(row["paper_id"])
        with self.transaction() as connection:
            connection.execute(
                "UPDATE papers SET withdrawn = 1, last_seen_at = ? WHERE paper_id = ?",
                (fetched_at.isoformat(), paper_id),
            )
            connection.execute(
                """INSERT INTO source_observations(
                       source, external_id, paper_id, payload_json,
                       source_updated_at, fetched_at, etag
                   ) VALUES (?, ?, ?, ?, ?, ?, NULL)
                   ON CONFLICT(source, external_id) DO UPDATE SET
                       paper_id=excluded.paper_id,
                       payload_json=excluded.payload_json,
                       source_updated_at=excluded.source_updated_at,
                       fetched_at=excluded.fetched_at""",
                (
                    source,
                    normalized,
                    paper_id,
                    encode_json(raw_payload),
                    source_updated_at.isoformat() if source_updated_at else None,
                    fetched_at.isoformat(),
                ),
            )
        return True

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
        items = self._rows_to_papers(rows[:limit])
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
        bounded = self._rows_to_papers(rows[:bounded_limit])
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
        return self._rows_to_papers(rows)

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
        return self._dataset_storage.start_import(
            dataset_key=dataset_key,
            source=source,
            source_path=source_path,
            source_size=source_size,
            source_mtime_ns=source_mtime_ns,
            started_at=started_at,
            run_token=run_token,
            lease_seconds=lease_seconds,
        )

    def get_dataset_import(self, dataset_key: str) -> dict[str, Any] | None:
        return self._dataset_storage.get_import(dataset_key)

    def list_dataset_imports(self, prefix: str = "") -> list[dict[str, Any]]:
        return self._dataset_storage.list_imports(prefix)

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
        return self._dataset_storage.apply_paper_batch(
            dataset_key=dataset_key,
            records=records,
            rejections=rejections,
            byte_offset=byte_offset,
            line_number=line_number,
            fetched_at=fetched_at,
            run_token=run_token,
            lease_seconds=lease_seconds,
        )

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
        return self._dataset_storage.apply_enrichment_batch(
            dataset_key=dataset_key,
            records=records,
            rejections=rejections,
            byte_offset=byte_offset,
            line_number=line_number,
            fetched_at=fetched_at,
            run_token=run_token,
            lease_seconds=lease_seconds,
        )

    def complete_dataset_import(
        self,
        dataset_key: str,
        completed_at: datetime,
        *,
        run_token: str,
    ) -> dict[str, Any]:
        return self._dataset_storage.complete_import(
            dataset_key,
            completed_at,
            run_token=run_token,
        )

    def pause_dataset_import(self, dataset_key: str, paused_at: datetime, *, run_token: str) -> dict[str, Any]:
        return self._dataset_storage.pause_import(
            dataset_key,
            paused_at,
            run_token=run_token,
        )

    def fail_dataset_import(self, dataset_key: str, error: str, failed_at: datetime, *, run_token: str) -> None:
        self._dataset_storage.fail_import(
            dataset_key,
            error,
            failed_at,
            run_token=run_token,
        )

    def reconcile_arxiv_dataset(self, dataset_key: str, source_path: str) -> dict[str, Any]:
        return self._dataset_storage.reconcile_arxiv_import(
            dataset_key,
            source_path,
        )

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

    def set_sync_state(
        self,
        source: str,
        etag: str | None,
        cursor: str | None,
        path: str | None,
        at: datetime,
        *,
        completed_through: datetime | None = None,
        window_from: str | None = None,
        window_until: str | None = None,
        mark_success: bool = True,
    ) -> None:
        self._connection.execute(
            """INSERT INTO sync_state(
                   source, etag, cursor, last_success_at, last_snapshot_path,
                   completed_through, window_from, window_until
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(source) DO UPDATE SET etag=excluded.etag, cursor=excluded.cursor,
               last_success_at=COALESCE(excluded.last_success_at, sync_state.last_success_at),
               last_snapshot_path=excluded.last_snapshot_path,
               completed_through=CASE
                   WHEN excluded.completed_through IS NULL THEN sync_state.completed_through
                   WHEN sync_state.completed_through IS NULL THEN excluded.completed_through
                   WHEN excluded.completed_through > sync_state.completed_through THEN excluded.completed_through
                   ELSE sync_state.completed_through
               END,
               window_from=COALESCE(excluded.window_from, sync_state.window_from),
               window_until=COALESCE(excluded.window_until, sync_state.window_until)""",
            (
                source,
                etag,
                cursor,
                at.isoformat() if mark_success else None,
                path,
                completed_through.isoformat() if completed_through else None,
                window_from,
                window_until,
            ),
        )
        self._connection.commit()

    def get_sync_state(self, source: str) -> dict[str, str | None]:
        row = self._connection.execute("SELECT * FROM sync_state WHERE source = ?", (source,)).fetchone()
        if not row:
            return {
                "etag": None,
                "cursor": None,
                "last_success_at": None,
                "last_snapshot_path": None,
                "completed_through": None,
                "window_from": None,
                "window_until": None,
            }
        return dict(row)

    def latest_source_update(self, source: str) -> datetime | None:
        row = self._connection.execute(
            "SELECT MAX(source_updated_at) AS latest FROM source_observations WHERE source = ?",
            (source,),
        ).fetchone()
        return parse_datetime(row["latest"]) if row and row["latest"] else None

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
            (
                batch_id,
                generated_at.isoformat(),
                score_version,
                sampling_seed,
                encode_json(feature_snapshot),
                encode_json(selected_paper_ids),
            ),
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
