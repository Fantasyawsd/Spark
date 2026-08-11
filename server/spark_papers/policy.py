from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Mapping


POLICY_VERSION = "ai-admission.v1"
DEFAULT_AI_SUBJECT_PREFIXES = ("cs.AI", "cs.LG", "cs.CL", "cs.CV", "cs.RO", "stat.ML")


@dataclass(frozen=True)
class AdmissionDecision:
    admitted: bool
    reason: str
    policy_version: str = POLICY_VERSION


class AiAdmissionPolicy:
    def __init__(
        self,
        subject_prefixes: Iterable[str] = DEFAULT_AI_SUBJECT_PREFIXES,
        openalex_topic_ids: Iterable[str] = (),
    ) -> None:
        self._subject_prefixes = tuple(subject_prefixes)
        self._openalex_topic_ids = frozenset(openalex_topic_ids)

    def evaluate(self, subjects: Iterable[str], signals: Mapping[str, Mapping[str, object]] | None = None) -> AdmissionDecision:
        normalized_subjects = {str(item).strip() for item in subjects if str(item).strip()}
        for subject in normalized_subjects:
            if any(subject == prefix or subject.startswith(prefix + ".") for prefix in self._subject_prefixes):
                return AdmissionDecision(True, f"arxiv_subject:{subject}")
        topics = (signals or {}).get("openalex", {}).get("topics", ())
        for topic in topics or ():
            topic_id = str(topic.get("id", topic) if isinstance(topic, Mapping) else topic)
            if topic_id in self._openalex_topic_ids:
                return AdmissionDecision(True, f"openalex_topic:{topic_id}")
        return AdmissionDecision(False, "no_ai_subject_or_topic")
