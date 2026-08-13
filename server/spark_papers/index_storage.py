from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta
from typing import Callable, Iterator


class IndexStorage:
    """Rebuilds and validates materialized paper indexes."""

    def __init__(
        self,
        connection: sqlite3.Connection,
        *,
        timestamp_factory: Callable[[], datetime],
    ) -> None:
        self._connection = connection
        self._timestamp_factory = timestamp_factory

    @contextmanager
    def _transaction(self) -> Iterator[sqlite3.Connection]:
        try:
            yield self._connection
            self._connection.commit()
        except Exception:
            self._connection.rollback()
            raise

    def refresh(self, generated_at: datetime | None = None) -> None:
        generated_at = generated_at or self._timestamp_factory()
        generated = generated_at.isoformat()
        self._refresh_latest(generated)
        self._refresh_channels(generated)
        self._refresh_candidates(generated_at, generated)

    def _refresh_latest(self, generated: str) -> None:
        with self._transaction() as connection:
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

    def _refresh_channels(self, generated: str) -> None:
        with self._transaction() as connection:
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

    def _refresh_candidates(self, generated_at: datetime, generated: str) -> None:
        with self._transaction() as connection:
            connection.execute("DELETE FROM candidate_index")
            connection.execute(
                """INSERT INTO candidate_index(pool, paper_id, generated_at, sort_key, published_at)
                   SELECT 'all', paper_id, ?, 0, published_at FROM papers
                   WHERE admitted = 1 AND withdrawn = 0""",
                (generated,),
            )
            boundaries = (
                ("0-1y", generated_at - timedelta(days=365.25), generated_at),
                (
                    "1-3y",
                    generated_at - timedelta(days=365.25 * 3),
                    generated_at - timedelta(days=365.25),
                ),
                (
                    "3-5y",
                    generated_at - timedelta(days=365.25 * 5),
                    generated_at - timedelta(days=365.25 * 3),
                ),
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
                date_params = [upper.isoformat()]
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
                        SELECT ?, paper_id, ?, {quality_sort}, published_at
                        FROM papers WHERE {quality_where}
                        ORDER BY {quality_sort} DESC, published_at DESC, paper_id DESC LIMIT 5000""",
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

    def is_ready(self) -> bool:
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
