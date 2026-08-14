from __future__ import annotations

from datetime import datetime
from typing import Iterable, Mapping


def _parse_year_counts(
    counts_by_year: Iterable[Mapping[str, object]] | Iterable[tuple[object, object]],
) -> dict[int, float]:
    rows: dict[int, float] = {}
    for entry in counts_by_year:
        if isinstance(entry, Mapping):
            year = entry.get('year')
            count = entry.get('cited_by_count')
        else:
            year, count = entry[0], entry[1]
        if year is None or count is None:
            continue
        try:
            parsed_year = int(year)
            parsed_count = float(count)
        except (TypeError, ValueError):
            continue
        if parsed_count < 0:
            continue
        rows[parsed_year] = parsed_count
    return rows


def compute_citation_velocities(
    counts_by_year: Iterable[Mapping[str, object]] | Iterable[tuple[object, object]],
    as_of: datetime,
) -> tuple[float | None, float | None]:
    """Return (citation_velocity, short_citation_velocity); missing parts stay None.

    citation_velocity averages citations across the trailing three calendar
    years (including the in-progress one). short_citation_velocity estimates
    the trailing-twelve-month citations by interpolating the current and
    previous calendar years at the as_of fraction, and requires both years;
    missing source data never masquerades as zero.
    """
    rows = _parse_year_counts(counts_by_year)
    current_year = as_of.year
    recent = [rows[year] for year in range(current_year - 2, current_year + 1) if year in rows]
    citation_velocity: float | None
    if len(recent) >= 2:
        citation_velocity = sum(recent) / 3.0
    else:
        citation_velocity = None
    this_year = rows.get(current_year)
    last_year = rows.get(current_year - 1)
    short_citation_velocity: float | None
    if this_year is None or last_year is None:
        short_citation_velocity = None
    else:
        year_start = datetime(current_year, 1, 1, tzinfo=as_of.tzinfo)
        fraction = (as_of - year_start).total_seconds() / (365.25 * 86400)
        fraction = min(max(fraction, 0.0), 1.0)
        short_citation_velocity = last_year * (1 - fraction) + this_year * fraction
    return citation_velocity, short_citation_velocity
