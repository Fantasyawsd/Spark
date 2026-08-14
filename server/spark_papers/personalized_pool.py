from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime
from typing import Mapping, Protocol

from .anonymous_profile import AnonymousProfile
from .models import PaperRecord
from .ports import PaperRepository


@dataclass(frozen=True)
class PersonalizedPoolConfig:
    max_subjects: int = 40
    max_keywords: int = 24
    max_venues: int = 20
    per_key_limit: int = 50
    min_weight: float = 0.05
    max_total: int = 500


class SimilarPaperRecallPort(Protocol):
    def recall(
        self,
        paper_id: str,
        limit: int,
        as_of: datetime | None = None,
    ) -> list[str]: ...


_TOKEN_PATTERN = re.compile(r"[a-z0-9]+")
_STOP_WORDS = frozenset(
    {"a", "an", "the", "of", "and", "or", "to", "in", "for", "with", "on", "by", "using", "learning", "towards"}
)


def _tokens(paper: PaperRecord) -> frozenset[str]:
    text = f"{paper.title} {paper.abstract or ''}".lower()
    return frozenset(token for token in _TOKEN_PATTERN.findall(text) if token not in _STOP_WORDS)


def _weighted_keys(values: Mapping[str, float], *, limit: int, min_weight: float) -> list[str]:
    return [
        key
        for key, _ in sorted(values.items(), key=lambda item: (-item[1], item[0]))
        if key and values[key] >= min_weight
    ][: max(0, limit)]


class TitleKeywordSimilarityRecall:
    def __init__(self, store: PaperRepository, *, per_subject_limit: int = 200, fallback_multiplier: int = 10) -> None:
        self.store = store
        self.per_subject_limit = max(1, per_subject_limit)
        self.fallback_multiplier = max(1, fallback_multiplier)

    def recall(
        self,
        paper_id: str,
        limit: int,
        as_of: datetime | None = None,
    ) -> list[str]:
        target = self.store.get(paper_id)
        limit = max(0, int(limit))
        if target is None or limit == 0:
            return []

        candidates: dict[str, PaperRecord] = {}
        for subject in target.subjects:
            papers, _ = self.store.list_papers(
                subject=subject,
                limit=self.per_subject_limit,
                admitted_only=True,
                to_date=as_of,
            )
            candidates.update((paper.paper_id, paper) for paper in papers)

        if len(candidates) < limit + 1:
            fallback, _ = self.store.list_papers(
                limit=max(limit * self.fallback_multiplier, limit + 1),
                admitted_only=True,
                to_date=as_of,
            )
            candidates.update((paper.paper_id, paper) for paper in fallback)

        candidates.pop(target.paper_id, None)
        target_tokens = _tokens(target)
        target_subjects = {subject.lower() for subject in target.subjects}

        def rank(paper: PaperRecord) -> tuple[bool, int, datetime, str]:
            same_subject = bool(target_subjects.intersection(subject.lower() for subject in paper.subjects))
            overlap = len(target_tokens.intersection(_tokens(paper)))
            return same_subject, overlap, paper.published_at, paper.paper_id

        ranked = sorted(candidates.values(), key=rank, reverse=True)
        return [paper.paper_id for paper in ranked[:limit]]


def build_personalized_candidates(
    store: PaperRepository,
    profile: AnonymousProfile,
    config: PersonalizedPoolConfig = PersonalizedPoolConfig(),
    as_of: datetime | None = None,
    similar_recall: SimilarPaperRecallPort | None = None,
) -> list[PaperRecord]:
    """召回画像候选；所有路径遵守同一个 as_of 发布时间上界（历史回放确定性）。

    性能边界：关键词召回为临时 LIKE 扫描方案，受 max_keywords=24 与
    per_key_limit=50 约束，仅适配当前单机库规模；库规模显著增长时应迁移
    FTS5/关键词索引（迁移边界见任务台账），向量 Embedding 经
    SimilarPaperRecallPort 替换基础实现。
    """
    subjects = _weighted_keys(profile.subjects, limit=config.max_subjects, min_weight=config.min_weight)
    keywords = _weighted_keys(profile.keywords, limit=config.max_keywords, min_weight=config.min_weight)
    venues = _weighted_keys(profile.venues, limit=config.max_venues, min_weight=config.min_weight)

    candidates: dict[str, PaperRecord] = {}
    subject_seeds: list[PaperRecord] = []

    def add(papers: list[PaperRecord]) -> None:
        for paper in papers:
            if paper.admitted and not paper.withdrawn:
                candidates.setdefault(paper.paper_id, paper)

    for subject in subjects:
        papers, _ = store.list_papers(
            subject=subject,
            limit=config.per_key_limit,
            admitted_only=True,
            to_date=as_of,
        )
        subject_seeds.extend(papers)
        add(papers)
    for venue in venues:
        papers, _ = store.list_papers(
            venue=venue,
            limit=config.per_key_limit,
            admitted_only=True,
            to_date=as_of,
        )
        add(papers)
    for keyword in keywords:
        add(
            store.list_papers_by_keyword(
                keyword,
                limit=config.per_key_limit,
                to_date=as_of,
            )
        )

    if similar_recall is not None:
        seen_seeds: set[str] = set()
        for seed in subject_seeds:
            if seed.paper_id in seen_seeds:
                continue
            seen_seeds.add(seed.paper_id)
            for paper_id in similar_recall.recall(seed.paper_id, limit=8, as_of=as_of):
                paper = store.get(paper_id)
                if paper is not None:
                    add([paper])
            if len(seen_seeds) == 3:
                break

    return list(candidates.values())[: max(0, config.max_total)]
