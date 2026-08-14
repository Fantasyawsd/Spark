from __future__ import annotations

import hashlib
import math
import random
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Iterable, Mapping

from . import SCORE_VERSION
from .anonymous_profile import AnonymousProfile
from .dto import recommendation_to_api
from .models import PaperRecord, RecommendationItem, parse_datetime, utc_now
from .personalized_pool import (
    SimilarPaperRecallPort,
    TitleKeywordSimilarityRecall,
    build_personalized_candidates,
)
from .ports import RecommendationRepository
from .preference_score import PreferenceScoreConfig, compute_user_preference
from .trend_boost import BoostConfig, compute_trend_boost

UTC = timezone.utc


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


def _number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
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


_UNKNOWN_SUBJECT = "__unknown__"
_ALL_SUBJECTS = "__all__"


def _subject_groups(paper: PaperRecord) -> frozenset[str]:
    """Return normalized subject groups used to compare signal distributions."""
    groups = frozenset(
        subject.strip().lower()
        for subject in paper.subjects
        if subject and subject.strip()
    )
    return groups or frozenset({_UNKNOWN_SUBJECT})


def _same_subject_group(left: PaperRecord, right: PaperRecord) -> bool:
    return bool(_subject_groups(left).intersection(_subject_groups(right)))


def _normalized_signal(paper: PaperRecord, name: str, candidates: Iterable[PaperRecord], as_of: datetime) -> float | None:
    value = _signal(paper, name, as_of)
    if value is None:
        return None
    comparison = tuple(candidates)
    if name != "freshness":
        bucket = age_bucket(paper.published_at, as_of)
        bucket_values = tuple(
            candidate
            for candidate in comparison
            if age_bucket(candidate.published_at, as_of) == bucket
            and _same_subject_group(paper, candidate)
        )
        if bucket_values:
            comparison = bucket_values
    all_values = [
        candidate_value
        for candidate_value in (_signal(candidate, name, as_of) for candidate in comparison)
        if candidate_value is not None
    ]
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
    boost = _trend_boost_for(paper, as_of, config)
    boosted_trend = trend * boost
    signals = {f"quality.{name}": value for name, value in quality_values.items()}
    signals.update({f"trend.{name}": value for name, value in trend_values.items()})
    signals["trend.boost"] = round(boost, 6)
    return quality, boosted_trend, signals


def _score_candidates(
    candidates: list[PaperRecord],
    config: ScoreConfig,
    as_of: datetime,
) -> list[tuple[PaperRecord, float, float, dict[str, float]]]:
    signal_names = tuple(dict.fromkeys(name for name, _ in (*config.quality_weights, *config.trend_weights)))
    distributions: dict[tuple[str, str, str], dict[str, float]] = {}
    for candidate in candidates:
        for name in signal_names:
            value = _signal(candidate, name, as_of)
            if value is None:
                continue
            bucket = "all" if name == "freshness" else age_bucket(candidate.published_at, as_of)
            subject_groups = (_ALL_SUBJECTS,) if name == "freshness" else _subject_groups(candidate)
            for subject_group in subject_groups:
                distributions.setdefault((name, bucket, subject_group), {})[candidate.paper_id] = value
    caps: dict[tuple[str, str, str], float] = {}
    for key, candidate_values in distributions.items():
        values = sorted(candidate_values.values())
        p99_index = max(0, min(len(values) - 1, math.ceil(len(values) * 0.99) - 1))
        caps[key] = values[p99_index]

    def normalized(paper: PaperRecord, name: str) -> float | None:
        value = _signal(paper, name, as_of)
        if value is None:
            return None
        bucket = "all" if name == "freshness" else age_bucket(paper.published_at, as_of)
        candidate_groups = (_ALL_SUBJECTS,) if name == "freshness" else _subject_groups(paper)
        matching_caps = [
            caps[(name, bucket, subject_group)]
            for subject_group in candidate_groups
            if (name, bucket, subject_group) in caps
        ]
        if not matching_caps:
            return None
        cap = max(matching_caps)
        transformed = math.log1p(min(value, cap))
        maximum = math.log1p(cap)
        return transformed / maximum if maximum > 0 else 0.0

    scored: list[tuple[PaperRecord, float, float, dict[str, float]]] = []
    for paper in candidates:
        quality_values = {
            name: value
            for name, _ in config.quality_weights
            if (value := normalized(paper, name)) is not None
        }
        trend_values = {
            name: value
            for name, _ in config.trend_weights
            if (value := normalized(paper, name)) is not None
        }
        quality_weight = sum(weight for name, weight in config.quality_weights if name in quality_values)
        trend_weight = sum(weight for name, weight in config.trend_weights if name in trend_values)
        quality = (
            sum(quality_values[name] * weight for name, weight in config.quality_weights if name in quality_values)
            / quality_weight
            if quality_weight
            else 0.0
        )
        trend = (
            sum(trend_values[name] * weight for name, weight in config.trend_weights if name in trend_values)
            / trend_weight
            if trend_weight
            else 0.0
        )
        boost = _trend_boost_for(paper, as_of, config)
        boosted_trend = trend * boost
        signals = {f"quality.{name}": value for name, value in quality_values.items()}
        signals.update({f"trend.{name}": value for name, value in trend_values.items()})
        signals["trend.boost"] = round(boost, 6)
        scored.append((paper, quality, boosted_trend, signals))
    return scored


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
    def __init__(
        self,
        store: RecommendationRepository,
        config: ScoreConfig = ScoreConfig(),
        similar_recall: SimilarPaperRecallPort | None = None,
    ) -> None:
        self.store = store
        self.config = config
        self.similar_recall = similar_recall or TitleKeywordSimilarityRecall(store)

    def generate(
        self,
        *,
        limit: int = 10,
        read_ids: Iterable[str] = (),
        seed: int | None = None,
        as_of: datetime | None = None,
        anonymous_profile: AnonymousProfile | None = None,
    ) -> tuple[str, list[RecommendationItem]]:
        limit = max(1, min(int(limit), 100))
        if as_of is None:
            as_of = utc_now()
            if seed is not None:
                as_of = as_of.replace(hour=23, minute=59, second=59)
        as_of = as_of.astimezone(UTC)
        read = set(list(read_ids)[:5000])
        candidates = self.store.recommendation_candidates(
            read_ids=read,
            per_pool_limit=max(limit * 50, 500),
            as_of=as_of,
        )
        personalization_enabled = (
            anonymous_profile is not None and self.config.personalized_pool_ratio > 0
        )
        personalized_candidate_ids: set[str] = set()
        if personalization_enabled:
            personalized = build_personalized_candidates(
                self.store,
                anonymous_profile,
                as_of=as_of,
                similar_recall=self.similar_recall,
            )
            personalized_candidate_ids = {paper.paper_id for paper in personalized}
            candidates = list(
                {
                    paper.paper_id: paper
                    for paper in (*candidates, *personalized)
                    if paper.paper_id not in read
                }.values()
            )
        effective_seed = seed if seed is not None else int(as_of.timestamp())
        if not candidates:
            return self._batch_id(effective_seed, as_of, limit, read, ()), []
        scored = _score_candidates(candidates, self.config, as_of)
        preferences: dict[str, float] = {}
        if personalization_enabled:
            for paper, _, _, signals in scored:
                preference = compute_user_preference(
                    paper,
                    anonymous_profile,
                    self.config.preference_config,
                    as_of=as_of,
                )
                if preference is not None:
                    signals["personalization.preference"] = round(preference, 6)
                    preferences[paper.paper_id] = preference
        quality_pool = sorted(scored, key=lambda item: (item[1], item[0].published_at, item[0].paper_id), reverse=True)[: max(limit * 8, 20)]
        trend_pool = sorted(scored, key=lambda item: (item[2], item[0].published_at, item[0].paper_id), reverse=True)[: max(limit * 8, 20)]
        personalized_pool = sorted(
            (
                item
                for item in scored
                if item[0].paper_id in personalized_candidate_ids
                and preferences.get(item[0].paper_id, 0.0) > 0
            ),
            key=lambda item: (
                preferences[item[0].paper_id],
                item[0].published_at,
                item[0].paper_id,
            ),
            reverse=True,
        )[: max(limit * 8, 20)]
        quality_ids = {item[0].paper_id for item in quality_pool}
        trend_ids = {item[0].paper_id for item in trend_pool}
        personalized_ids = {item[0].paper_id for item in personalized_pool}
        by_id = {paper.paper_id: (paper, quality, trend, signals) for paper, quality, trend, signals in scored}
        rng = random.Random(effective_seed)
        quotas = _allocate_quotas(limit, self.config.age_bucket_targets, candidates, as_of)
        selected: list[RecommendationItem] = []
        remaining = set(by_id)
        personalized_target = (
            round(limit * self.config.personalized_pool_ratio)
            if personalization_enabled
            else 0
        )
        high_target = round(
            (limit - personalized_target) * self.config.quality_pool_ratio
        )
        personalized_count = 0
        high_count = 0
        trend_count = 0
        last_author: str | None = None
        last_subjects: set[str] = set()
        for bucket, quota in quotas.items():
            for _ in range(quota):
                if personalized_count < personalized_target:
                    desired_pool = "personalized"
                elif high_count < high_target:
                    desired_pool = "high_impact"
                else:
                    desired_pool = "trending"
                options: list[tuple[PaperRecord, float, float, dict[str, float], str, float]] = []
                for paper_id in sorted(remaining):
                    paper, quality, trend, signals = by_id[paper_id]
                    if age_bucket(paper.published_at, as_of) != bucket:
                        continue
                    in_quality = paper_id in quality_ids
                    in_trend = paper_id in trend_ids
                    in_personalized = paper_id in personalized_ids
                    if desired_pool == "personalized" and not in_personalized:
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
                    score = (
                        preferences[paper_id]
                        if pool == "personalized"
                        else quality if pool == "high_impact" else trend
                    )
                    options.append((paper, quality, trend, signals, pool, max(score, 0.001)))
                if not options:
                    options = _fallback_options(
                        remaining,
                        by_id,
                        desired_pool,
                        bucket,
                        as_of,
                        last_author,
                        last_subjects,
                        quality_ids,
                        trend_ids,
                        personalized_ids,
                        preferences,
                        enforce_diversity=False,
                    )
                if not options:
                    options = _fallback_options(
                        remaining,
                        by_id,
                        None,
                        bucket,
                        as_of,
                        last_author,
                        last_subjects,
                        quality_ids,
                        trend_ids,
                        personalized_ids,
                        preferences,
                        enforce_diversity=False,
                    )
                if not options:
                    break
                chosen = _weighted_choice(options, rng)
                paper, quality, trend, signals, pool, weight = chosen
                remaining.remove(paper.paper_id)
                selected.append(
                    RecommendationItem(
                        paper,
                        pool,
                        bucket,
                        quality,
                        min(trend, 1.0),
                        preferences.get(paper_id, 0.0),
                        weight,
                        signals,
                    )
                )
                if pool == "personalized":
                    personalized_count += 1
                elif pool == "high_impact":
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
            selected.append(
                RecommendationItem(
                    paper,
                    pool,
                    age_bucket(paper.published_at, as_of),
                    quality,
                    min(trend, 1.0),
                    preferences.get(paper_id, 0.0),
                    weight,
                    signals,
                )
            )
        selected = [
            RecommendationItem(
                self.store.get(item.paper.paper_id) or item.paper,
                item.pool,
                item.age_bucket,
                item.quality_score,
                item.trend_score,
                item.personalization_score,
                item.recommendation_weight,
                item.signals,
            )
            for item in selected
        ]
        selected_ids = tuple(item.paper.paper_id for item in selected)
        batch_id = self._batch_id(effective_seed, as_of, limit, read, selected_ids)
        self.store.record_batch(batch_id, as_of, self.config.version, effective_seed, {item.paper.paper_id: recommendation_to_api(item) for item in selected}, list(selected_ids))
        return batch_id, selected

    def _batch_id(
        self,
        seed: int,
        as_of: datetime,
        limit: int,
        read_ids: Iterable[str],
        selected_ids: Iterable[str],
    ) -> str:
        read_key = ",".join(sorted(set(read_ids)))
        selected_key = ",".join(selected_ids)
        value = (
            f"{self.config.version}:{seed}:{as_of.date().isoformat()}:"
            f"{limit}:{read_key}:{selected_key}"
        )
        return "batch_" + hashlib.sha256(value.encode()).hexdigest()[:20]


def _fallback_options(
    remaining: set[str],
    by_id: Mapping[str, tuple[PaperRecord, float, float, dict[str, float]]],
    desired_pool: str | None,
    bucket: str,
    as_of: datetime,
    last_author: str | None,
    last_subjects: set[str],
    quality_ids: set[str],
    trend_ids: set[str],
    personalized_ids: set[str],
    preferences: Mapping[str, float],
    *,
    enforce_diversity: bool,
) -> list[tuple[PaperRecord, float, float, dict[str, float], str, float]]:
    options = []
    for paper_id in sorted(remaining):
        paper, quality, trend, signals = by_id[paper_id]
        if age_bucket(paper.published_at, as_of) != bucket:
            continue
        in_quality = paper_id in quality_ids
        in_trend = paper_id in trend_ids
        in_personalized = paper_id in personalized_ids
        if desired_pool == "personalized" and not in_personalized:
            continue
        if desired_pool == "high_impact" and not in_quality:
            continue
        if desired_pool == "trending" and not in_trend:
            continue
        if desired_pool != "personalized" and not in_quality and not in_trend:
            continue
        author = paper.authors[0].lower() if paper.authors else ""
        subjects = {subject.lower() for subject in paper.subjects}
        if enforce_diversity and (
            (last_author and author == last_author) or last_subjects.intersection(subjects)
        ):
            continue
        pool = desired_pool
        if pool is None:
            if in_quality and (not in_trend or quality >= trend):
                pool = "high_impact"
            else:
                pool = "trending"
        score = (
            preferences[paper_id]
            if pool == "personalized"
            else quality if pool == "high_impact" else trend
        )
        options.append((paper, quality, trend, signals, pool, max(score, 0.001)))
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
