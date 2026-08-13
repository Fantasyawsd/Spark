from __future__ import annotations

import unittest

from spark_papers.identity_resolution import (
    FUZZY_REVIEW_THRESHOLD,
    IdentityResolutionAction,
    needs_fuzzy_lookup,
    resolve_identity,
)


class IdentityResolutionTest(unittest.TestCase):
    def test_one_exact_match_selects_existing_paper(self) -> None:
        resolution = resolve_identity(
            "incoming",
            exact_match_ids={"existing"},
            has_external_ids=True,
            best_fuzzy_candidate=None,
            allow_create=False,
        )

        self.assertEqual(resolution.action, IdentityResolutionAction.STORE)
        self.assertEqual(resolution.target_paper_id, "existing")
        self.assertIsNone(resolution.review)

    def test_conflicting_exact_matches_require_review(self) -> None:
        resolution = resolve_identity(
            "incoming",
            exact_match_ids={"first", "second"},
            has_external_ids=True,
            best_fuzzy_candidate=None,
            allow_create=True,
        )

        self.assertEqual(resolution.action, IdentityResolutionAction.CONFLICT)
        self.assertIsNone(resolution.target_paper_id)
        self.assertIsNotNone(resolution.review)
        assert resolution.review is not None
        self.assertEqual(resolution.review.reason, "conflicting_exact_identity")
        self.assertEqual(resolution.review.confidence, 1.0)

    def test_external_identity_skips_and_ignores_fuzzy_candidate(self) -> None:
        self.assertFalse(needs_fuzzy_lookup(set(), has_external_ids=True))

        resolution = resolve_identity(
            "incoming",
            exact_match_ids=set(),
            has_external_ids=True,
            best_fuzzy_candidate=("candidate", 1.0),
            allow_create=True,
        )

        self.assertEqual(resolution.action, IdentityResolutionAction.STORE)
        self.assertEqual(resolution.target_paper_id, "incoming")
        self.assertIsNone(resolution.review)

    def test_no_identity_requests_fuzzy_lookup(self) -> None:
        self.assertTrue(needs_fuzzy_lookup(set(), has_external_ids=False))
        self.assertFalse(needs_fuzzy_lookup({"existing"}, has_external_ids=False))

    def test_fuzzy_candidate_at_threshold_is_queued_without_automatic_merge(self) -> None:
        resolution = resolve_identity(
            "incoming",
            exact_match_ids=set(),
            has_external_ids=False,
            best_fuzzy_candidate=("candidate", FUZZY_REVIEW_THRESHOLD),
            allow_create=True,
        )

        self.assertEqual(resolution.action, IdentityResolutionAction.STORE)
        self.assertEqual(resolution.target_paper_id, "incoming")
        self.assertIsNotNone(resolution.review)
        assert resolution.review is not None
        self.assertEqual(resolution.review.candidate_paper_id, "candidate")
        self.assertEqual(resolution.review.reason, "fuzzy_candidate_requires_review")

    def test_enrichment_with_fuzzy_candidate_is_unmatched_and_queued_for_review(self) -> None:
        resolution = resolve_identity(
            "incoming",
            exact_match_ids=set(),
            has_external_ids=False,
            best_fuzzy_candidate=("candidate", FUZZY_REVIEW_THRESHOLD + 0.01),
            allow_create=False,
        )

        self.assertEqual(resolution.action, IdentityResolutionAction.UNMATCHED)
        self.assertIsNone(resolution.target_paper_id)
        self.assertIsNotNone(resolution.review)
        assert resolution.review is not None
        self.assertEqual(resolution.review.reason, "fuzzy_candidate_requires_review")

    def test_enrichment_below_fuzzy_threshold_queues_identity_not_found(self) -> None:
        resolution = resolve_identity(
            "incoming",
            exact_match_ids=set(),
            has_external_ids=False,
            best_fuzzy_candidate=("candidate", FUZZY_REVIEW_THRESHOLD - 0.01),
            allow_create=False,
        )

        self.assertEqual(resolution.action, IdentityResolutionAction.UNMATCHED)
        self.assertIsNotNone(resolution.review)
        assert resolution.review is not None
        self.assertIsNone(resolution.review.candidate_paper_id)
        self.assertEqual(resolution.review.confidence, 0.0)
        self.assertEqual(resolution.review.reason, "enrichment_identity_not_found")

    def test_create_without_any_match_keeps_incoming_paper_id(self) -> None:
        resolution = resolve_identity(
            "incoming",
            exact_match_ids=set(),
            has_external_ids=False,
            best_fuzzy_candidate=None,
            allow_create=True,
        )

        self.assertEqual(resolution.action, IdentityResolutionAction.STORE)
        self.assertEqual(resolution.target_paper_id, "incoming")
        self.assertIsNone(resolution.review)


if __name__ == "__main__":
    unittest.main()
