from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from .anonymous_profile import AnonymousProfile
from .models import PaperRecord


@dataclass(frozen=True)
class PreferenceScoreConfig:
    subject_weight: float = 0.5
    venue_weight: float = 0.2
    keyword_weight: float = 0.3


def compute_user_preference(
    paper: PaperRecord,
    profile: AnonymousProfile,
    config: PreferenceScoreConfig = PreferenceScoreConfig(),
    as_of: datetime | None = None,
) -> float | None:
    del as_of  # Reserved for future time-decayed preference signals.
    components: list[tuple[float, float]] = []

    subject_total = sum(profile.subjects.values())
    if subject_total:
        matched = sum(
            weight
            for subject, weight in profile.subjects.items()
            if subject in paper.subjects
        )
        if matched:
            components.append((matched / subject_total, config.subject_weight))

    venue_total = sum(profile.venues.values())
    if venue_total:
        venue = next(
            (
                value
                for key in ("venue_name", "venue_label")
                if isinstance((value := paper.metadata.get(key)), str)
                and value in profile.venues
            ),
            None,
        )
        if venue is not None:
            components.append((profile.venues[venue] / venue_total, config.venue_weight))

    normalized_keywords: dict[str, float] = {}
    for key, weight in profile.keywords.items():
        normalized = key.strip().lower()
        # 单字关键词噪声大，不参与匹配。
        if normalized and len(normalized) >= 2:
            normalized_keywords[normalized] = normalized_keywords.get(normalized, 0.0) + weight
    keyword_total = sum(normalized_keywords.values())
    if keyword_total:
        # 子串匹配同时支持英文 token 与中文/短语关键词。
        text = f"{paper.title} {paper.abstract or ''}".lower()
        matched = sum(weight for key, weight in normalized_keywords.items() if key in text)
        if matched:
            components.append((matched / keyword_total, config.keyword_weight))

    total_weight = sum(weight for _, weight in components)
    if not components or not total_weight:
        return None
    score = sum(value * weight for value, weight in components) / total_weight
    return max(0.0, min(score, 1.0))
