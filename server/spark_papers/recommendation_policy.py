"""Versioned recommendation policy; no persistence or transport dependencies."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from . import SCORE_VERSION
from .preference_score import PreferenceScoreConfig
from .trend_boost import BoostConfig


@dataclass(frozen=True)
class ScoreConfig:
    version: str = SCORE_VERSION
    quality_pool_ratio: float = 0.6
    trend_pool_ratio: float = 0.4
    personalized_pool_ratio: float = 0.4
    preference_config: PreferenceScoreConfig = PreferenceScoreConfig()
    age_bucket_targets: tuple[tuple[str, float], ...] = (
        ("0-1y", 0.40),
        ("1-3y", 0.30),
        ("3-5y", 0.15),
        ("5y+", 0.15),
    )
    quality_weights: tuple[tuple[str, float], ...] = (
        ("citation_count", 0.35),
        ("citation_velocity", 0.25),
        ("github_stars", 0.20),
        ("venue_score", 0.20),
    )
    trend_weights: tuple[tuple[str, float], ...] = (
        ("hf_heat", 0.25),
        ("github_star_velocity", 0.20),
        ("short_citation_velocity", 0.15),
        ("freshness", 0.20),
        ("web_heat", 0.20),
    )
    boost: BoostConfig = BoostConfig()


def age_bucket(published_at: datetime, as_of: datetime) -> str:
    years = max((as_of - published_at).total_seconds() / (365.25 * 86400), 0)
    if years <= 1:
        return "0-1y"
    if years <= 3:
        return "1-3y"
    if years <= 5:
        return "3-5y"
    return "5y+"
