from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class BoostConfig:
    """Versioned configuration for the short-lived trend boost."""

    window_hours: float = 72.0
    half_life_hours: float = 24.0
    gain: float = 1.0

    def __post_init__(self) -> None:
        if self.window_hours <= 0:
            raise ValueError("window_hours must be positive")
        if self.half_life_hours <= 0:
            raise ValueError("half_life_hours must be positive")
        if self.gain < 0:
            raise ValueError("gain must be non-negative")


def compute_trend_boost(
    trend_detected_at: datetime | None,
    as_of: datetime,
    config: BoostConfig = BoostConfig(),
) -> float:
    """Return a deterministic multiplier in [1, 1 + gain] for a hot paper.

    Papers without a verified trend_detected_at, with future timestamps, or
    outside the configured window receive no boost (1.0). Inside the window
    the extra gain decays exponentially with the configured half life:
    1 + gain * 2 ** (-age_hours / half_life_hours).
    """
    if trend_detected_at is None:
        return 1.0
    age_hours = (as_of - trend_detected_at).total_seconds() / 3600
    if age_hours < 0 or age_hours > config.window_hours:
        return 1.0
    decay = math.pow(2.0, -age_hours / config.half_life_hours)
    return 1.0 + config.gain * decay
