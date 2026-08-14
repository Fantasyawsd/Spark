from __future__ import annotations

import unittest
from datetime import datetime, timezone

from spark_papers.models import PaperRecord
from spark_papers.storage import PaperStore
from spark_papers.trend_scout import (
    TrendCandidate,
    TrendScoutRunner,
)

UTC = timezone.utc


class StaticLlm:
    """Minimal mocked TrendScoutLlmPort returning a fixed candidate list."""

    def __init__(self, candidates: list[TrendCandidate]) -> None:
        self.candidates = candidates

    def discover(self, as_of: datetime) -> list[TrendCandidate]:
        return list(self.candidates)


def _seed_paper(
    store: PaperStore,
    *,
    paper_id: str,
    title: str,
    arxiv_id: str | None = None,
    admitted: bool = True,
    withdrawn: bool = False,
) -> None:
    external_ids: dict[str, str] = {}
    if arxiv_id:
        external_ids["arxiv_id"] = arxiv_id
    paper = PaperRecord(
        paper_id=paper_id,
        title=title,
        abstract="Abstract",
        authors=("Ada Lovelace",),
        published_at=datetime(2026, 7, 1, tzinfo=UTC),
        updated_at=None,
        subjects=("cs.AI",),
        external_ids=external_ids,
        discovery_sources=("arxiv",) if arxiv_id else (),
        admitted=admitted,
        withdrawn=withdrawn,
    )
    store.ingest(
        paper,
        source="arxiv",
        external_id=arxiv_id or title,
        raw_payload={"title": paper.title},
        fetched_at=datetime(2026, 8, 1, tzinfo=UTC),
    )


def _candidate(
    title: str,
    *,
    arxiv_id: str | None = None,
    doi: str | None = None,
    score: float = 0.87,
    mentions: int = 42,
    source_count: int = 7,
) -> TrendCandidate:
    return TrendCandidate(
        title=title,
        arxiv_id=arxiv_id,
        doi=doi,
        web_mentions=mentions,
        web_source_count=source_count,
        web_heat_score=score,
        trend_reason="Hacker News discussion spike",
        trend_topics=("multimodal", "reasoning"),
        evidence={"urls": ["https://news.example.com/thread"]},
    )


class TrendCandidateValidationTest(unittest.TestCase):
    def test_rejects_empty_title(self) -> None:
        with self.assertRaises(ValueError):
            TrendCandidate(title="   ")

    def test_rejects_negative_mentions(self) -> None:
        with self.assertRaises(ValueError):
            TrendCandidate(title="Paper", web_mentions=-1)

    def test_rejects_negative_source_count(self) -> None:
        with self.assertRaises(ValueError):
            TrendCandidate(title="Paper", web_source_count=-1)

    def test_rejects_out_of_range_score(self) -> None:
        with self.assertRaises(ValueError):
            TrendCandidate(title="Paper", web_heat_score=1.5)
        with self.assertRaises(ValueError):
            TrendCandidate(title="Paper", web_heat_score=-0.1)

    def test_accepts_boundary_score(self) -> None:
        candidate = TrendCandidate(title="Paper", web_heat_score=0.0)
        self.assertEqual(candidate.web_heat_score, 0.0)


class ExactMatchWriteTest(unittest.TestCase):
    def test_admitted_match_writes_full_payload(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(store, paper_id="paper-web-1", title="Trending Transformer Architecture", arxiv_id="2608.00010")
            now = datetime(2026, 8, 14, tzinfo=UTC)
            llm = StaticLlm([
                _candidate(
                    "A Trending Transformer Architecture",
                    arxiv_id="2608.00010",
                    score=0.93,
                    mentions=120,
                    source_count=15,
                )
            ])
            runner = TrendScoutRunner(store, llm)
            report = runner.run(as_of=now)
            self.assertEqual(report.written, 1)
            self.assertEqual(report.matched, 1)
            self.assertEqual(report.queued, 0)
            self.assertEqual(report.skipped, 0)
            paper = store.get("paper-web-1")
            self.assertIsNotNone(paper)
            heat = paper.signals["web_heat"]
            self.assertEqual(heat["web_heat_score"], 0.93)
            self.assertEqual(heat["web_mentions"], 120)
            self.assertEqual(heat["web_source_count"], 15)
            self.assertEqual(heat["trend_detected_at"], now.isoformat())
            self.assertEqual(heat["trend_reason"], "Hacker News discussion spike")
            self.assertEqual(heat["trend_topics"], ["multimodal", "reasoning"])
            self.assertEqual(heat["evidence"], {"urls": ["https://news.example.com/thread"]})
            provenance = [item for item in paper.provenance if item.field_name == "web_heat"]
            self.assertEqual(len(provenance), 1)
            self.assertEqual(provenance[0].source, "web_heat")
        finally:
            store.close()

    def test_match_by_doi(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(store, paper_id="paper-doi-1", title="Model Context Optimization")
            store._connection.execute(
                "INSERT INTO paper_external_ids(id_type, id_value, paper_id) VALUES ('doi', '10.1234/example', 'paper-doi-1')"
            )
            store._connection.commit()
            llm = StaticLlm([_candidate("Model Context Optimization", doi="10.1234/example")])
            report = TrendScoutRunner(store, llm).run(as_of=datetime(2026, 8, 14, tzinfo=UTC))
            self.assertEqual(report.written, 1)
            self.assertIn("web_heat", store.get("paper-doi-1").signals)
        finally:
            store.close()

    def test_withdrawn_match_is_not_written(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(
                store,
                paper_id="paper-withdrawn-1",
                title="Withdrawn Paper",
                arxiv_id="2608.00020",
                withdrawn=True,
            )
            llm = StaticLlm([_candidate("Withdrawn Paper", arxiv_id="2608.00020")])
            report = TrendScoutRunner(store, llm).run(as_of=datetime(2026, 8, 14, tzinfo=UTC))
            self.assertEqual(report.written, 0)
            self.assertEqual(report.skipped, 1)
            paper = store.get("paper-withdrawn-1")
            self.assertNotIn("web_heat", paper.signals)
        finally:
            store.close()

    def test_unadmitted_match_is_not_written(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(
                store,
                paper_id="paper-unadmitted-1",
                title="Unadmitted Paper",
                arxiv_id="2608.00030",
                admitted=False,
            )
            llm = StaticLlm([_candidate("Unadmitted Paper", arxiv_id="2608.00030")])
            report = TrendScoutRunner(store, llm).run(as_of=datetime(2026, 8, 14, tzinfo=UTC))
            self.assertEqual(report.written, 0)
            self.assertNotIn("web_heat", store.get("paper-unadmitted-1").signals)
        finally:
            store.close()

    def test_title_mismatch_exact_match_is_rejected(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(
                store,
                paper_id="paper-mismatch-1",
                title="Completely Different Subject Matter",
                arxiv_id="2608.00040",
            )
            llm = StaticLlm([_candidate("A Totally Unrelated Trend", arxiv_id="2608.00040", score=0.95)])
            report = TrendScoutRunner(store, llm).run(as_of=datetime(2026, 8, 14, tzinfo=UTC))
            self.assertEqual(report.written, 0)
            self.assertEqual(report.skipped, 1)
            paper = store.get("paper-mismatch-1")
            self.assertNotIn("web_heat", paper.signals)
            queue_rows = store._connection.execute(
                "SELECT COUNT(*) AS total FROM match_queue"
            ).fetchone()
            self.assertEqual(queue_rows["total"], 0)
        finally:
            store.close()


class FuzzyQueueTest(unittest.TestCase):
    def test_high_confidence_fuzzy_match_is_queued(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(store, paper_id="paper-fuzzy-1", title="A Trending Transformer Architecture")
            llm = StaticLlm([_candidate("A Trending Transformer Architecture", score=0.92)])
            report = TrendScoutRunner(store, llm).run(as_of=datetime(2026, 8, 14, tzinfo=UTC))
            self.assertEqual(report.queued, 1)
            self.assertEqual(report.written, 0)
            self.assertNotIn("web_heat", store.get("paper-fuzzy-1").signals)
            rows = store._connection.execute(
                "SELECT source, external_id, candidate_paper_id, confidence, reason, payload_json FROM match_queue"
            ).fetchall()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["source"], "trend_scout")
            self.assertEqual(rows[0]["candidate_paper_id"], "paper-fuzzy-1")
            self.assertEqual(rows[0]["confidence"], 1.0)
            self.assertEqual(rows[0]["reason"], "trend scout fuzzy candidate")
        finally:
            store.close()

    def test_low_confidence_fuzzy_match_is_skipped(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(store, paper_id="paper-fuzzy-low-1", title="A Trending Transformer Architecture")
            llm = StaticLlm([_candidate("Unrelated Scientific Study About Zebras", score=0.3)])
            report = TrendScoutRunner(store, llm).run(as_of=datetime(2026, 8, 14, tzinfo=UTC))
            self.assertEqual(report.skipped, 1)
            self.assertEqual(report.queued, 0)
            queue_rows = store._connection.execute(
                "SELECT COUNT(*) AS total FROM match_queue"
            ).fetchone()
            self.assertEqual(queue_rows["total"], 0)
        finally:
            store.close()


class NoMatchTest(unittest.TestCase):
    def test_no_match_leaves_store_unchanged(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(store, paper_id="paper-unrelated-1", title="Existing Paper")
            before = store.count()
            llm = StaticLlm([_candidate("Unmatched Unknown Trend", score=0.5)])
            report = TrendScoutRunner(store, llm).run(as_of=datetime(2026, 8, 14, tzinfo=UTC))
            self.assertEqual(report.skipped, 1)
            self.assertEqual(report.written, 0)
            self.assertEqual(report.queued, 0)
            self.assertEqual(store.count(), before)
            self.assertNotIn("web_heat", store.get("paper-unrelated-1").signals)
            queue_rows = store._connection.execute(
                "SELECT COUNT(*) AS total FROM match_queue"
            ).fetchone()
            self.assertEqual(queue_rows["total"], 0)
        finally:
            store.close()


class ReportCountersTest(unittest.TestCase):
    def test_mixed_run_counts_each_outcome(self) -> None:
        store = PaperStore(":memory:")
        try:
            _seed_paper(store, paper_id="paper-a", title="Alpha Trending Work", arxiv_id="2608.00050")
            _seed_paper(store, paper_id="paper-b", title="Beta Fuzzy Work")
            now = datetime(2026, 8, 14, tzinfo=UTC)
            llm = StaticLlm([
                _candidate("Alpha Trending Work", arxiv_id="2608.00050", score=0.9),
                _candidate("Beta Fuzzy Work", score=0.91),
                _candidate("Nothing Matches This", score=0.5),
            ])
            report = TrendScoutRunner(store, llm).run(as_of=now)
            self.assertEqual(report.candidates, 3)
            self.assertEqual(report.matched, 1)
            self.assertEqual(report.written, 1)
            self.assertEqual(report.queued, 1)
            self.assertEqual(report.skipped, 1)
            self.assertEqual(report.written + report.queued + report.skipped, report.candidates)
        finally:
            store.close()


if __name__ == "__main__":
    unittest.main()
