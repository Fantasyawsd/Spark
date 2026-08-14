from __future__ import annotations

from datetime import datetime, timedelta
from typing import Iterable

DEFAULT_WINDOW_DAYS = 30


def compute_star_velocity(
    observations: Iterable[tuple[datetime, int]],
    as_of: datetime,
    *,
    window_days: int = DEFAULT_WINDOW_DAYS,
) -> float | None:
    """Return stars/day over the trailing window, or None without enough history.

    Only observations inside '[as_of - window_days, as_of]' participate. A
    value is produced only when at least two distinct observations fall inside
    the window; missing history never masquerades as zero growth. A real star
    loss is clamped to '0.0' so the signal stays non-negative for scoring.
    """
    if window_days <= 0:
        raise ValueError("window_days must be positive")
    points = sorted(
        (observed_at, int(stars))
        for observed_at, stars in observations
        if observed_at is not None and stars is not None
    )
    if len(points) < 2:
        return None
    window_start = as_of - timedelta(days=window_days)
    windowed = [
        (observed_at, stars)
        for observed_at, stars in points
        if window_start <= observed_at <= as_of
    ]
    if len(windowed) < 2:
        return None
    first, last = windowed[0], windowed[-1]
    delta_days = (last[0] - first[0]).total_seconds() / 86400
    if delta_days <= 0:
        return None
    delta_stars = last[1] - first[1]
    return max(0.0, delta_stars / delta_days)
