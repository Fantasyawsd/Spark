from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Collection


FUZZY_REVIEW_THRESHOLD = 0.65


class IdentityResolutionAction(str, Enum):
    STORE = "store"
    UNMATCHED = "unmatched"
    CONFLICT = "conflict"


@dataclass(frozen=True)
class IdentityReview:
    candidate_paper_id: str | None
    confidence: float
    reason: str


@dataclass(frozen=True)
class IdentityResolution:
    action: IdentityResolutionAction
    target_paper_id: str | None = None
    review: IdentityReview | None = None


def needs_fuzzy_lookup(
    exact_match_ids: Collection[str],
    *,
    has_external_ids: bool,
) -> bool:
    return not exact_match_ids and not has_external_ids


def resolve_identity(
    incoming_paper_id: str,
    *,
    exact_match_ids: Collection[str],
    has_external_ids: bool,
    best_fuzzy_candidate: tuple[str, float] | None,
    allow_create: bool,
) -> IdentityResolution:
    exact_matches = tuple(exact_match_ids)
    if len(exact_matches) == 1:
        return IdentityResolution(
            IdentityResolutionAction.STORE,
            target_paper_id=exact_matches[0],
        )
    if len(exact_matches) > 1:
        return IdentityResolution(
            IdentityResolutionAction.CONFLICT,
            review=IdentityReview(
                candidate_paper_id=None,
                confidence=1.0,
                reason="conflicting_exact_identity",
            ),
        )

    fuzzy_candidate = None if has_external_ids else best_fuzzy_candidate
    review = None
    if fuzzy_candidate is not None and fuzzy_candidate[1] >= FUZZY_REVIEW_THRESHOLD:
        review = IdentityReview(
            candidate_paper_id=fuzzy_candidate[0],
            confidence=fuzzy_candidate[1],
            reason="fuzzy_candidate_requires_review",
        )

    if allow_create:
        return IdentityResolution(
            IdentityResolutionAction.STORE,
            target_paper_id=incoming_paper_id,
            review=review,
        )
    if review is not None:
        return IdentityResolution(
            IdentityResolutionAction.UNMATCHED,
            review=review,
        )
    return IdentityResolution(
        IdentityResolutionAction.UNMATCHED,
        review=IdentityReview(
            candidate_paper_id=None,
            confidence=0.0,
            reason="enrichment_identity_not_found",
        ),
    )
