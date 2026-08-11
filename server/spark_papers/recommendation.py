from __future__ import annotations

import hashlib
import math
import random
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Iterable, Mapping

from . import SCORE_VERSION
from .dto import recommendation_to_api
from .models import PaperRecord, RecommendationItem, utc_now
from .ports import RecommendationRepository

UTC = timezone.utc


@dataclass(frozen=True)
class ScoreConfig:
    version: str = SCORE_VERSION
    quality_pool_ratio: float = 0.6
    trend_pool_ratio: float = 0.4
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
        ("hf_heat", 0.30),
        ("github_star_velocity", 0.25),
        ("short_citation_velocity", 0.20),
        ("freshness", 0.25),
    )


def _number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) and number >= 0 else None


def _signal(paper: PaperRecord, name: str) -> float | None:
    openalex = paper.signals.get("openalex", {})
    semantic = paper.signals.get("semantic_scholar", {})
    github = paper.signals.get("github", {})
    hf = paper.signals.get("huggingface", {})
    values = {
        "citation_count": _first_number(openalex.get("citation_count"), semantic.get("citation_count")),
        "citation_velocity": _first_number(openalex.get("citation_velocity"), semantic.get("citation_velocity")),
        "github_stars": _number(github.get("stars")),
        "venue_score": _number(paper.metadata.get("venue_score")),
        "hf_heat": _first_number(hf.get("heat"), hf.get("upvotes")),
        "github_star_velocity": _number(github.get("star_velocity")),
        "short_citation_velocity": _first_number(openalex.get("short_citation_velocity"), semantic.get("short_citation_velocity")),
    }
    if name == "freshness":
        age_days = max((datetime.now(UTC) - paper.published_at).total_seconds() / 86400, 0)
        values[name] = math.exp(-age_days / 365.0)
    return values.get(name)


def _first_number(*values: Any) -> float | None:
    for value in values:
        parsed = _number(value)
        if parsed is not None:
            return parsed
    return None


def _normalized_signal(paper: PaperRecord, name: str, candidates: Iterable[PaperRecord], as_of: datetime) -> float | None:
    value = _signal(paper, name)
    if value is None:
        return None
    comparison = tuple(candidates)
    if name != "freshness":
        bucket = age_bucket(paper.published_at, as_of)
        bucket_values = tuple(candidate for candidate in comparison if age_bucket(candidate.published_at, as_of) == bucket)
        if bucket_values:
            comparison = bucket_values
    all_values = [candidate_value for candidate_value in (_signal(candidate, name) for candidate in comparison) if candidate_value is not None]
    if not all_values:
        return None
    # Log scaling prevents one extreme paper from consuming the whole pool.
    p99_index = max(0, min(len(all_values) - 1, math.ceil(len(all_values) * 0.99) - 1))
    cap = sorted(all_values)[p99_index]
    transformed = math.log1p(min(value, cap))
    maximum = math.log1p(cap)
    return transformed / maximum if maximum > 0 else 0.0


def score_paper(paper: PaperRecord, candidates: Iterable[PaperRecord], config: ScoreConfig = ScoreConfig(), as_of: datetime | None = None) -> tuple[float, float, dict[str, float]]:
    candidates = tuple(candidates)
    as_of = as_of or utc_now()
    quality_values: dict[str, float] = {}
    quality_weight = 0.0
    for name, weight in config.quality_weights:
        normalized = _normalized_signal(paper, name, candidates, as_of)
        if normalized is not None:
            quality_values[name] = normalized
            quality_weight += weight
    quality = sum(quality_values[name] * weight for name, weight in config.quality_weights if name in quality_values) / quality_weight if quality_weight else 0.0

    trend_values: dict[str, float] = {}
    trend_weight = 0.0
    for name, weight in config.trend_weights:
        normalized = _normalized_signal(paper, name, candidates, as_of)
        if normalized is not None:
            trend_values[name] = normalized
            trend_weight += weight
    trend = sum(trend_values[name] * weight for name, weight in config.trend_weights if name in trend_values) / trend_weight if trend_weight else 0.0
    signals = {f"quality.{name}": value for name, value in quality_values.items()}
    signals.update({f"trend.{name}": value for name, value in trend_values.items()})
    return quality, trend, signals


def age_bucket(published_at: datetime, as_of: datetime) -> str:
    years = max((as_of - published_at).total_seconds() / (365.25 * 86400), 0)
    if years <= 1:
        return "0-1y"
    if years <= 3:
        return "1-3y"
    if years <= 5:
        return "3-5y"
    return "5y+"


class RecommendationEngine:
    def __init__(self, store: RecommendationRepository, config: ScoreConfig = ScoreConfig()) -> None:
        self.store = store
        self.config = config

    def generate(
        self,
        *,
        limit: int = 10,
        read_ids: Iterable[str] = (),
        seed: int | None = None,
        as_of: datetime | None = None,
    ) -> tuple[str, list[RecommendationItem]]:
        limit = max(1, min(int(limit), 100))
        if as_of is None:
            as_of = utc_now()
            if seed is not None:
                as_of = as_of.replace(hour=0, minute=0, second=0)
        as_of = as_of.astimezone(UTC)
        read = set(list(read_ids)[:5000])
        candidates = [paper for paper in self.store.all_candidates() if paper.paper_id not in read]
        if not candidates:
            return self._batch_id(seed or 0, as_of), []
        scored: list[tuple[PaperRecord, float, float, dict[str, float]]] = []
        for paper in candidates:
            quality, trend, signals = score_paper(paper, candidates, self.config, as_of)
            scored.append((paper, quality, trend, signals))
        quality_pool = sorted(scored, key=lambda item: (item[1], item[0].published_at, item[0].paper_id), reverse=True)[: max(limit * 8, 20)]
        trend_pool = sorted(scored, key=lambda item: (item[2], item[0].published_at, item[0].paper_id), reverse=True)[: max(limit * 8, 20)]
        by_id = {paper.paper_id: (paper, quality, trend, signals) for paper, quality, trend, signals in scored}
        rng = random.Random(seed if seed is not None else int(as_of.timestamp()))
        quotas = _allocate_quotas(limit, self.config.age_bucket_targets, candidates, as_of)
        selected: list[RecommendationItem] = []
        remaining = set(by_id)
        high_target = round(limit * self.config.quality_pool_ratio)
        trend_target = limit - high_target
        high_count = 0
        trend_count = 0
        last_author: str | None = None
        last_subjects: set[str] = set()
        for bucket, quota in quotas.items():
            for _ in range(quota):
                desired_pool = "high_impact" if high_count < high_target else "trending"
                options: list[tuple[PaperRecord, float, float, dict[str, float], str, float]] = []
                for paper_id in sorted(remaining):
                    paper, quality, trend, signals = by_id[paper_id]
                    if age_bucket(paper.published_at, as_of) != bucket:
                        continue
                    in_quality = any(item[0].paper_id == paper_id for item in quality_pool)
                    in_trend = any(item[0].paper_id == paper_id for item in trend_pool)
                    if not in_quality and not in_trend:
                        continue
                    if desired_pool == "high_impact" and not in_quality:
                        continue
                    if desired_pool == "trending" and not in_trend:
                        continue
                    author = paper.authors[0].lower() if paper.authors else ""
                    subjects = {subject.lower() for subject in paper.subjects}
                    if last_author and author == last_author or last_subjects.intersection(subjects):
                        continue
                    pool = desired_pool
                    score = quality if pool == "high_impact" else trend
                    options.append((paper, quality, trend, signals, pool, max(score, 0.001)))
                if not options:
                    options = _fallback_options(remaining, by_id, desired_pool, last_author, last_subjects, quality_pool, trend_pool)
                if not options:
                    break
                chosen = _weighted_choice(options, rng)
                paper, quality, trend, signals, pool, weight = chosen
                remaining.remove(paper.paper_id)
                selected.append(RecommendationItem(paper, pool, bucket, quality, trend, weight, signals))
                if pool == "high_impact":
                    high_count += 1
                else:
                    trend_count += 1
                last_author = paper.authors[0].lower() if paper.authors else None
                last_subjects = {subject.lower() for subject in paper.subjects}
        while len(selected) < limit and remaining:
            options = []
            for paper_id in sorted(remaining):
                paper, quality, trend, signals = by_id[paper_id]
                pool = "high_impact" if quality >= trend else "trending"
                options.append((paper, quality, trend, signals, pool, max(max(quality, trend), 0.001)))
            paper, quality, trend, signals, pool, weight = _weighted_choice(options, rng)
            remaining.remove(paper.paper_id)
            selected.append(RecommendationItem(paper, pool, age_bucket(paper.published_at, as_of), quality, trend, weight, signals))
        batch_id = self._batch_id(seed if seed is not None else int(as_of.timestamp()), as_of)
        self.store.record_batch(batch_id, as_of, self.config.version, seed if seed is not None else int(as_of.timestamp()), {item.paper.paper_id: recommendation_to_api(item) for item in selected}, [item.paper.paper_id for item in selected])
        return batch_id, selected

    def _batch_id(self, seed: int, as_of: datetime) -> str:
        value = f"{self.config.version}:{seed}:{as_of.date().isoformat()}"
        return "batch_" + hashlib.sha256(value.encode()).hexdigest()[:20]


def _fallback_options(
    remaining: set[str],
    by_id: Mapping[str, tuple[PaperRecord, float, float, dict[str, float]]],
    desired_pool: str,
    last_author: str | None,
    last_subjects: set[str],
    quality_pool: Iterable[tuple[PaperRecord, float, float, dict[str, float]]],
    trend_pool: Iterable[tuple[PaperRecord, float, float, dict[str, float]]],
) -> list[tuple[PaperRecord, float, float, dict[str, float], str, float]]:
    allowed = {item[0].paper_id for item in (quality_pool if desired_pool == "high_impact" else trend_pool)}
    options = []
    for paper_id in sorted(remaining):
        if paper_id not in allowed:
            continue
        paper, quality, trend, signals = by_id[paper_id]
        author = paper.authors[0].lower() if paper.authors else ""
        subjects = {subject.lower() for subject in paper.subjects}
        if last_author and author == last_author or last_subjects.intersection(subjects):
            continue
        score = quality if desired_pool == "high_impact" else trend
        options.append((paper, quality, trend, signals, desired_pool, max(score, 0.001)))
    return options


def _allocate_quotas(limit: int, targets: tuple[tuple[str, float], ...], candidates: list[PaperRecord], as_of: datetime) -> dict[str, int]:
    available = {bucket: sum(age_bucket(paper.published_at, as_of) == bucket for paper in candidates) for bucket, _ in targets}
    raw = {bucket: limit * target for bucket, target in targets}
    quotas = {bucket: min(available[bucket], int(value)) for bucket, value in raw.items()}
    remaining = limit - sum(quotas.values())
    while remaining > 0:
        choices = sorted(targets, key=lambda item: (raw[item[0]] - quotas[item[0]], available[item[0]] - quotas[item[0]]), reverse=True)
        added = False
        for bucket, _ in choices:
            if quotas[bucket] < available[bucket]:
                quotas[bucket] += 1
                remaining -= 1
                added = True
                if remaining == 0:
                    break
        if not added:
            break
    return quotas


def _weighted_choice(options: list[tuple[Any, ...]], rng: random.Random) -> tuple[Any, ...]:
    total = sum(float(item[-1]) for item in options)
    threshold = rng.random() * total
    for item in options:
        threshold -= float(item[-1])
        if threshold <= 0:
            return item
    return options[-1]
