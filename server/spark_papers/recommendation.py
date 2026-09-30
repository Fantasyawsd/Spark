"""Recommendation use case: gather, score, sample, hydrate and persist domain data."""
from __future__ import annotations

import hashlib
from dataclasses import replace
from datetime import datetime, timezone
from itertools import islice
from typing import Iterable

from .anonymous_profile import AnonymousProfile
from .models import PaperRecord, RecommendationBatch, RecommendationItem, utc_now
from .personalized_pool import (
    SimilarPaperRecallPort, TitleKeywordSimilarityRecall, build_personalized_candidates,
)
from .ports import RecommendationRepository
from .preference_score import compute_user_preference
from .recommendation_policy import ScoreConfig, age_bucket
from .recommendation_sampling import RecommendationSampler
from .recommendation_scoring import ScoredPaper, score_candidates, score_paper

# Preserve existing public imports used by CLI, indexes and tests.
__all__ = ["RecommendationEngine", "ScoreConfig", "age_bucket", "score_paper"]
UTC = timezone.utc


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
        read = set(islice(read_ids, 5000))
        personalization_enabled = (
            anonymous_profile is not None and self.config.personalized_pool_ratio > 0
        )
        candidates, personalized_ids = self._candidates(
            limit, read, as_of, anonymous_profile if personalization_enabled else None,
        )
        effective_seed = seed if seed is not None else int(as_of.timestamp())
        if not candidates:
            return self._batch_id(effective_seed, as_of, limit, read, ()), []
        scored = score_candidates(candidates, self.config, as_of)
        preferences = self._preferences(
            scored, anonymous_profile if personalization_enabled else None, as_of,
        )
        selected = RecommendationSampler(
            scored, self.config, limit=limit, as_of=as_of, seed=effective_seed,
            preferences=preferences, personalized_candidate_ids=personalized_ids,
            personalization_enabled=personalization_enabled,
        ).sample()
        selected = [replace(item, paper=self.store.get(item.paper.paper_id) or item.paper)
                    for item in selected]
        selected_ids = tuple(item.paper.paper_id for item in selected)
        batch_id = self._batch_id(effective_seed, as_of, limit, read, selected_ids)
        self.store.save_recommendation_batch(RecommendationBatch(
            batch_id=batch_id, generated_at=as_of, score_version=self.config.version,
            sampling_seed=effective_seed, items=tuple(selected),
        ))
        return batch_id, selected

    def _candidates(
        self, limit: int, read: set[str], as_of: datetime,
        profile: AnonymousProfile | None,
    ) -> tuple[list[PaperRecord], set[str]]:
        candidates = self.store.recommendation_candidates(
            read_ids=read, per_pool_limit=max(limit * 50, 500), as_of=as_of,
        )
        if profile is None:
            return candidates, set()
        personalized = build_personalized_candidates(
            self.store, profile, as_of=as_of, similar_recall=self.similar_recall,
        )
        personalized_ids = {paper.paper_id for paper in personalized}
        candidates = list({paper.paper_id: paper for paper in (*candidates, *personalized)
                           if paper.paper_id not in read}.values())
        return candidates, personalized_ids

    def _preferences(
        self, scored: list[ScoredPaper], profile: AnonymousProfile | None, as_of: datetime,
    ) -> dict[str, float]:
        preferences: dict[str, float] = {}
        if profile is None:
            return preferences
        for entry in scored:
            preference = compute_user_preference(
                entry.paper, profile, self.config.preference_config, as_of=as_of,
            )
            if preference is not None:
                entry.signals["personalization.preference"] = round(preference, 6)
                preferences[entry.paper.paper_id] = preference
        return preferences

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
