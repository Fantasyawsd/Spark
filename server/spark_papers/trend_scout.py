from __future__ import annotations

import json
import os
import sys
import urllib.request
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping, Protocol

from .identity import normalized_title
from .models import PaperRecord, utc_now


@dataclass(frozen=True)
class TrendCandidate:
    """A web-trend discovery candidate produced by an LLM adapter."""

    title: str
    arxiv_id: str | None = None
    doi: str | None = None
    web_mentions: int = 0
    web_source_count: int = 0
    web_heat_score: float = 0.0
    trend_reason: str = ""
    trend_topics: tuple[str, ...] = ()
    evidence: Mapping[str, Any] | None = None

    def __post_init__(self) -> None:
        if not self.title.strip():
            raise ValueError("title must not be empty")
        if self.web_mentions < 0:
            raise ValueError("web_mentions must be non-negative")
        if self.web_source_count < 0:
            raise ValueError("web_source_count must be non-negative")
        if not 0.0 <= self.web_heat_score <= 1.0:
            raise ValueError("web_heat_score must be within [0, 1]")


@dataclass(frozen=True)
class TrendScoutReport:
    """Outcome counters for one trend scout run."""

    matched: int
    written: int
    queued: int
    skipped: int
    as_of: datetime
    candidates: int


class TrendScoutLlmPort(Protocol):
    def discover(self, as_of: datetime) -> list[TrendCandidate]: ...


class TrendScoutStore(Protocol):
    def get(self, paper_id: str) -> PaperRecord | None: ...

    def find_by_external_ids(self, external_ids: Mapping[str, str]) -> set[str]: ...

    def find_fuzzy_candidates(self, title: str, author: str, limit: int = 5) -> list[tuple[str, float]]: ...

    def queue_match(
        self,
        source: str,
        external_id: str,
        candidate_paper_id: str | None,
        confidence: float,
        reason: str,
        payload: Mapping[str, Any],
    ) -> None: ...

    def record_web_heat(
        self,
        paper_id: str,
        web_heat: Mapping[str, Any],
        *,
        as_of: datetime | None = None,
    ) -> bool: ...


_FUZZY_QUEUE_THRESHOLD = 0.90


class TrendScoutRunner:
    """Verify trend candidates against the store and record web-heat signals."""

    def __init__(self, store: TrendScoutStore, llm: TrendScoutLlmPort) -> None:
        self.store = store
        self.llm = llm

    def run(self, *, as_of: datetime | None = None) -> TrendScoutReport:
        as_of = as_of or utc_now()
        candidates = self.llm.discover(as_of)
        matched = 0
        written = 0
        queued = 0
        skipped = 0
        for candidate in candidates:
            exact_ids = _candidate_external_ids(candidate)
            if exact_ids is None:
                # No verifiable external identity: fall through to fuzzy match.
                if self._queue_fuzzy(candidate, as_of):
                    queued += 1
                else:
                    skipped += 1
                continue
            exact_paper_ids = self.store.find_by_external_ids(exact_ids)
            if not exact_paper_ids:
                if self._queue_fuzzy(candidate, as_of):
                    queued += 1
                else:
                    skipped += 1
                continue
            matched += 1
            target = self._valid_exact_match(exact_paper_ids, candidate)
            if target is not None:
                payload = _web_heat_payload(candidate, as_of)
                if self.store.record_web_heat(target, payload, as_of=as_of):
                    written += 1
                else:
                    skipped += 1
            else:
                # Exact ID hit but the paper is withdrawn, not admitted, or the
                # title disagrees with the candidate: reject without writing.
                skipped += 1
        return TrendScoutReport(
            matched=matched,
            written=written,
            queued=queued,
            skipped=skipped,
            as_of=as_of,
            candidates=len(candidates),
        )

    def _valid_exact_match(
        self,
        paper_ids: set[str],
        candidate: TrendCandidate,
    ) -> str | None:
        for paper_id in sorted(paper_ids):
            paper = self.store.get(paper_id)
            if paper is None:
                continue
            if not paper.admitted or paper.withdrawn:
                continue
            if not _titles_overlap(paper.title, candidate.title):
                continue
            return paper_id
        return None

    def _queue_fuzzy(self, candidate: TrendCandidate, as_of: datetime) -> bool:
        fuzzy = self.store.find_fuzzy_candidates(candidate.title, "", limit=1)
        if not fuzzy:
            return False
        candidate_paper_id, confidence = fuzzy[0]
        if confidence < _FUZZY_QUEUE_THRESHOLD:
            return False
        external_id = candidate.arxiv_id or candidate.doi or candidate.title
        self.store.queue_match(
            source="trend_scout",
            external_id=external_id,
            candidate_paper_id=candidate_paper_id,
            confidence=confidence,
            reason="trend scout fuzzy candidate",
            payload=dict(
                _web_heat_payload(candidate, as_of),
                candidate_paper_id=candidate_paper_id,
                confidence=confidence,
            ),
        )
        return True


def _candidate_external_ids(candidate: TrendCandidate) -> Mapping[str, str] | None:
    external_ids: dict[str, str] = {}
    if candidate.arxiv_id:
        external_ids["arxiv_id"] = candidate.arxiv_id
    elif candidate.doi:
        external_ids["doi"] = candidate.doi
    return external_ids or None


def _web_heat_payload(candidate: TrendCandidate, as_of: datetime) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "web_heat_score": candidate.web_heat_score,
        "web_mentions": candidate.web_mentions,
        "web_source_count": candidate.web_source_count,
        "trend_detected_at": as_of.isoformat(),
        "trend_reason": candidate.trend_reason,
        "trend_topics": list(candidate.trend_topics),
    }
    if candidate.evidence is not None:
        payload["evidence"] = dict(candidate.evidence)
    return payload


def _titles_overlap(left_title: str, right_title: str) -> bool:
    left = normalized_title(left_title)
    right = normalized_title(right_title)
    if not left or not right:
        return False
    return left in right or right in left


class HttpTrendScoutLlm:
    """POST trend discovery requests to an LLM chat-completions endpoint.

    The response is expected to be a JSON array under choices[0].message.content.
    Requires SPARK_TREND_SCOUT_BASE_URL and SPARK_TREND_SCOUT_API_KEY; the key is
    read from the environment at call time and never logged.
    """

    def __init__(
        self,
        *,
        base_url: str | None = None,
        api_key: str | None = None,
        timeout: float = 30.0,
    ) -> None:
        self.base_url = base_url or os.environ.get(
            "SPARK_TREND_SCOUT_BASE_URL",
            "https://api.deepseek.com/chat/completions",
        )
        self._api_key_provider = (
            (lambda: api_key)
            if api_key is not None
            else (lambda: os.environ.get("SPARK_TREND_SCOUT_API_KEY"))
        )
        self.timeout = timeout

    def discover(self, as_of: datetime) -> list[TrendCandidate]:
        api_key = self._api_key_provider()
        if not api_key:
            raise RuntimeError("trend scout LLM is not configured")
        body = json.dumps(
            {
                "model": os.environ.get("SPARK_TREND_SCOUT_MODEL", "deepseek-chat"),
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "Return a JSON array of trending paper candidates. Each item is an object "
                            "with keys: title (string, required), arxiv_id, doi, web_mentions (int >= 0), "
                            "web_source_count (int >= 0), web_heat_score (float 0-1), trend_reason, "
                            "trend_topics (array of strings), evidence (object)."
                        ),
                    },
                    {
                        "role": "user",
                        "content": f"Find trending papers to track as of {as_of.isoformat()}.",
                    },
                ],
            }
        ).encode("utf-8")
        request = urllib.request.Request(
            self.base_url,
            data=body,
            method="POST",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        with urllib.request.urlopen(request, timeout=self.timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
        content = _extract_message_content(payload)
        if content is None:
            print("trend scout: response has no choices[0].message.content", file=sys.stderr)
            return []
        try:
            raw_items = json.loads(content)
        except (TypeError, ValueError, json.JSONDecodeError) as error:
            print(f"trend scout: failed to parse LLM JSON output: {error}", file=sys.stderr)
            return []
        if not isinstance(raw_items, list):
            print("trend scout: expected a JSON array of candidates", file=sys.stderr)
            return []
        candidates: list[TrendCandidate] = []
        for item in raw_items:
            if not isinstance(item, Mapping):
                continue
            try:
                candidates.append(_candidate_from_mapping(item))
            except (TypeError, ValueError, KeyError):
                continue
        return candidates


def _extract_message_content(payload: Any) -> str | None:
    if not isinstance(payload, Mapping):
        return None
    choices = payload.get("choices")
    if not isinstance(choices, list) or not choices:
        return None
    message = choices[0].get("message")
    if not isinstance(message, Mapping):
        return None
    content = message.get("content")
    return str(content) if content is not None else None


def _candidate_from_mapping(item: Mapping[str, Any]) -> TrendCandidate:
    topics = item.get("trend_topics")
    if isinstance(topics, list):
        topics = tuple(str(value) for value in topics)
    else:
        topics = tuple()
    evidence = item.get("evidence")
    return TrendCandidate(
        title=str(item.get("title") or "").strip(),
        arxiv_id=_optional_str(item.get("arxiv_id")),
        doi=_optional_str(item.get("doi")),
        web_mentions=int(item.get("web_mentions") or 0),
        web_source_count=int(item.get("web_source_count") or 0),
        web_heat_score=float(item.get("web_heat_score") or 0.0),
        trend_reason=str(item.get("trend_reason") or ""),
        trend_topics=topics,
        evidence=dict(evidence) if isinstance(evidence, Mapping) else None,
    )


def _optional_str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
