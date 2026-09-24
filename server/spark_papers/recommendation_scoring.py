"""Pure, shared scoring path for single-paper and batch recommendation callers."""
from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any, Iterable, NamedTuple

from .models import PaperRecord, parse_datetime, utc_now
from .recommendation_policy import ScoreConfig, age_bucket
from .trend_boost import compute_trend_boost

UTC = timezone.utc
_UNKNOWN_SUBJECT = "__unknown__"
_ALL_SUBJECTS = "__all__"


class ScoredPaper(NamedTuple):
    paper: PaperRecord
    quality: float
    trend: float
    signals: dict[str, float]


def _number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return number if math.isfinite(number) and number >= 0 else None


def _signal(paper: PaperRecord, name: str, as_of: datetime | None = None) -> float | None:
    openalex = paper.signals.get("openalex", {})
    semantic = paper.signals.get("semantic_scholar", {})
    github = paper.signals.get("github", {})
    hf = paper.signals.get("huggingface", {})
    web_heat = paper.signals.get("web_heat", {})
    openalex_is_outlier = openalex.get("citation_count_outlier") is True
    values = {
        "citation_count": _first_number(
            None if openalex_is_outlier else openalex.get("citation_count"),
            None if openalex_is_outlier else semantic.get("citation_count"),
        ),
        "citation_velocity": _first_number(
            None if openalex_is_outlier else openalex.get("citation_velocity"),
            None if openalex_is_outlier else semantic.get("citation_velocity"),
        ),
        "github_stars": _number(github.get("stars")),
        "venue_score": _number(paper.metadata.get("venue_score")),
        "hf_heat": _first_number(hf.get("heat"), hf.get("upvotes")),
        "github_star_velocity": _number(github.get("star_velocity")),
        "short_citation_velocity": _first_number(
            None if openalex_is_outlier else openalex.get("short_citation_velocity"),
            None if openalex_is_outlier else semantic.get("short_citation_velocity"),
        ),
        "web_heat": _number(web_heat.get("web_heat_score")),
    }
    if name == "freshness":
        age_days = max(((as_of or datetime.now(UTC)) - paper.published_at).total_seconds() / 86400, 0)
        values[name] = math.exp(-age_days / 365.0)
    return values.get(name)


def _first_number(*values: Any) -> float | None:
    for value in values:
        parsed = _number(value)
        if parsed is not None:
            return parsed
    return None


def _trend_boost_for(paper: PaperRecord, as_of: datetime, config: ScoreConfig) -> float:
    web_heat = paper.signals.get("web_heat") or {}
    detected_at = parse_datetime(web_heat.get("trend_detected_at"))
    return compute_trend_boost(detected_at, as_of, config.boost)


def _subject_groups(paper: PaperRecord) -> frozenset[str]:
    """Return normalized subject groups used to compare signal distributions."""
    groups = frozenset(
        subject.strip().lower()
        for subject in paper.subjects
        if subject and subject.strip()
    )
    return groups or frozenset({_UNKNOWN_SUBJECT})


class _SignalNormalizer:
    """Prepare the production P99 caps once for a comparison population."""

    def __init__(
        self, candidates: Iterable[PaperRecord], config: ScoreConfig, as_of: datetime,
    ) -> None:
        self.as_of = as_of
        names = tuple(dict.fromkeys(
            name for name, _ in (*config.quality_weights, *config.trend_weights)
        ))
        distributions: dict[tuple[str, str, str], dict[str, float]] = {}
        for paper in candidates:
            for name in names:
                value = _signal(paper, name, as_of)
                if value is None:
                    continue
                bucket = "all" if name == "freshness" else age_bucket(paper.published_at, as_of)
                groups = (_ALL_SUBJECTS,) if name == "freshness" else _subject_groups(paper)
                for group in groups:
                    distributions.setdefault((name, bucket, group), {})[paper.paper_id] = value
        self.caps: dict[tuple[str, str, str], float] = {}
        for key, candidate_values in distributions.items():
            values = sorted(candidate_values.values())
            index = max(0, min(len(values) - 1, math.ceil(len(values) * 0.99) - 1))
            self.caps[key] = values[index]

    def normalize(self, paper: PaperRecord, name: str) -> float | None:
        value = _signal(paper, name, self.as_of)
        if value is None:
            return None
        bucket = "all" if name == "freshness" else age_bucket(paper.published_at, self.as_of)
        groups = (_ALL_SUBJECTS,) if name == "freshness" else _subject_groups(paper)
        matching = [self.caps[(name, bucket, group)] for group in groups
                    if (name, bucket, group) in self.caps]
        if not matching:
            return None
        cap = max(matching)
        transformed = math.log1p(min(value, cap))
        maximum = math.log1p(cap)
        return transformed / maximum if maximum > 0 else 0.0


def _score(
    paper: PaperRecord, config: ScoreConfig, normalizer: _SignalNormalizer,
) -> ScoredPaper:
    quality_values = {
        name: value for name, _ in config.quality_weights
        if (value := normalizer.normalize(paper, name)) is not None
    }
    trend_values = {
        name: value for name, _ in config.trend_weights
        if (value := normalizer.normalize(paper, name)) is not None
    }
    quality_weight = sum(weight for name, weight in config.quality_weights if name in quality_values)
    trend_weight = sum(weight for name, weight in config.trend_weights if name in trend_values)
    quality = (
        sum(quality_values[name] * weight for name, weight in config.quality_weights if name in quality_values)
        / quality_weight if quality_weight else 0.0
    )
    trend = (
        sum(trend_values[name] * weight for name, weight in config.trend_weights if name in trend_values)
        / trend_weight if trend_weight else 0.0
    )
    boost = _trend_boost_for(paper, normalizer.as_of, config)
    signals = {f"quality.{name}": value for name, value in quality_values.items()}
    signals.update({f"trend.{name}": value for name, value in trend_values.items()})
    signals["trend.boost"] = round(boost, 6)
    return ScoredPaper(paper, quality, trend * boost, signals)


def score_candidates(
    candidates: Iterable[PaperRecord], config: ScoreConfig, as_of: datetime,
) -> list[ScoredPaper]:
    candidates = tuple(candidates)
    normalizer = _SignalNormalizer(candidates, config, as_of)
    return [_score(paper, config, normalizer) for paper in candidates]


def score_paper(
    paper: PaperRecord,
    candidates: Iterable[PaperRecord],
    config: ScoreConfig = ScoreConfig(),
    as_of: datetime | None = None,
) -> tuple[float, float, dict[str, float]]:
    """Use the same normalization as the batch path, including multi-subject P99.

    The supplied candidates determine the comparison caps. A target outside
    their subject/age groups has no comparable signal. Include the target in
    candidates to score it in isolation, as the production batch path does.
    """
    normalizer = _SignalNormalizer(candidates, config, as_of or utc_now())
    scored = _score(paper, config, normalizer)
    return scored.quality, scored.trend, scored.signals
