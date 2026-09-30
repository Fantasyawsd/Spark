"""Pure seeded sampling, pool quotas, diversity fallback and tail filling."""
from __future__ import annotations

import random
from dataclasses import dataclass
from datetime import datetime
from typing import Mapping

from .models import PaperRecord, RecommendationItem
from .recommendation_policy import ScoreConfig, age_bucket
from .recommendation_scoring import ScoredPaper


@dataclass(frozen=True)
class _Option:
    scored: ScoredPaper
    pool: str
    weight: float


class RecommendationSampler:
    """Request-local selection state; never reads a repository or serializes JSON."""

    def __init__(
        self, scored: list[ScoredPaper], config: ScoreConfig, *,
        limit: int, as_of: datetime, seed: int,
        preferences: Mapping[str, float], personalized_candidate_ids: set[str],
        personalization_enabled: bool,
    ) -> None:
        self.config = config
        self.limit = limit
        self.as_of = as_of
        self.rng = random.Random(seed)
        self.preferences = preferences
        self.by_id = {entry.paper.paper_id: entry for entry in scored}
        self.quotas = _allocate_quotas(
            limit, config.age_bucket_targets, [entry.paper for entry in scored], as_of,
        )
        pool_limit = max(limit * 8, 20)
        quality = sorted(scored, key=lambda e: (e.quality, e.paper.published_at, e.paper.paper_id), reverse=True)
        trend = sorted(scored, key=lambda e: (e.trend, e.paper.published_at, e.paper.paper_id), reverse=True)
        personalized = sorted(
            (entry for entry in scored if entry.paper.paper_id in personalized_candidate_ids
             and preferences.get(entry.paper.paper_id, 0.0) > 0),
            key=lambda e: (preferences[e.paper.paper_id], e.paper.published_at, e.paper.paper_id),
            reverse=True,
        )
        self.pool_ids = {
            "high_impact": {e.paper.paper_id for e in quality[:pool_limit]},
            "trending": {e.paper.paper_id for e in trend[:pool_limit]},
            "personalized": {e.paper.paper_id for e in personalized[:pool_limit]},
        }
        self.personalized_target = round(limit * config.personalized_pool_ratio) if personalization_enabled else 0
        self.high_target = round((limit - self.personalized_target) * config.quality_pool_ratio)
        self.remaining = set(self.by_id)
        self.selected: list[RecommendationItem] = []
        self.counts = {"personalized": 0, "high_impact": 0, "trending": 0}
        self.last_author: str | None = None
        self.last_subjects: set[str] = set()

    def sample(self) -> list[RecommendationItem]:
        for bucket, quota in self.quotas.items():
            for _ in range(quota):
                desired = self._desired_pool()
                options = self._options(bucket, desired, enforce_diversity=True)
                if not options:
                    options = self._options(bucket, desired, enforce_diversity=False)
                if not options:
                    options = self._options(bucket, None, enforce_diversity=False)
                if not options:
                    break
                self._take(_weighted_choice(options, self.rng), bucket)
        self._fill_tail()
        return self.selected

    def _desired_pool(self) -> str:
        if self.counts["personalized"] < self.personalized_target:
            return "personalized"
        if self.counts["high_impact"] < self.high_target:
            return "high_impact"
        return "trending"

    def _options(
        self, bucket: str, desired: str | None, *, enforce_diversity: bool,
    ) -> list[_Option]:
        options = []
        for paper_id in sorted(self.remaining):
            entry = self.by_id[paper_id]
            paper = entry.paper
            if age_bucket(paper.published_at, self.as_of) != bucket:
                continue
            in_quality = paper_id in self.pool_ids["high_impact"]
            in_trend = paper_id in self.pool_ids["trending"]
            if desired is not None and paper_id not in self.pool_ids[desired]:
                continue
            if desired != "personalized" and not in_quality and not in_trend:
                continue
            author = paper.authors[0].lower() if paper.authors else ""
            subjects = {subject.lower() for subject in paper.subjects}
            if enforce_diversity and (
                (self.last_author and author == self.last_author)
                or self.last_subjects.intersection(subjects)
            ):
                continue
            pool = desired
            if pool is None:
                pool = "high_impact" if in_quality and (not in_trend or entry.quality >= entry.trend) else "trending"
            score = (self.preferences[paper_id] if pool == "personalized"
                     else entry.quality if pool == "high_impact" else entry.trend)
            options.append(_Option(entry, pool, max(score, 0.001)))
        return options

    def _take(self, option: _Option, bucket: str) -> None:
        entry = option.scored
        paper = entry.paper
        self.remaining.remove(paper.paper_id)
        self.selected.append(RecommendationItem(
            paper=paper,
            pool=option.pool,
            age_bucket=bucket,
            quality_score=entry.quality,
            trend_score=min(entry.trend, 1.0),
            personalization_score=(self.preferences.get(paper.paper_id, 0.0)
                                   if option.pool == "personalized" else 0.0),
            recommendation_weight=option.weight,
            signals=entry.signals,
        ))
        self.counts[option.pool] += 1
        self.last_author = paper.authors[0].lower() if paper.authors else None
        self.last_subjects = {subject.lower() for subject in paper.subjects}

    def _fill_tail(self) -> None:
        while len(self.selected) < self.limit and self.remaining:
            options = []
            for paper_id in sorted(self.remaining):
                entry = self.by_id[paper_id]
                pool = "high_impact" if entry.quality >= entry.trend else "trending"
                options.append(_Option(entry, pool, max(max(entry.quality, entry.trend), 0.001)))
            option = _weighted_choice(options, self.rng)
            self._take(option, age_bucket(option.scored.paper.published_at, self.as_of))


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


def _weighted_choice(options: list[_Option], rng: random.Random) -> _Option:
    total = sum(float(item.weight) for item in options)
    threshold = rng.random() * total
    for item in options:
        threshold -= float(item.weight)
        if threshold <= 0:
            return item
    return options[-1]
