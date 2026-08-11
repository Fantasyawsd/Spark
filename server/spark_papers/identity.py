from __future__ import annotations

import hashlib
import re
from difflib import SequenceMatcher
from typing import Iterable, Mapping


ARXIV_RE = re.compile(r"(?:https?://arxiv\.org/(?:abs|pdf)/)?(?:arXiv:)?([0-9]{4}\.[0-9]{4,5})(?:v[0-9]+)?", re.I)


def normalize_arxiv_id(value: str | None) -> str | None:
    if not value:
        return None
    match = ARXIV_RE.search(value.strip())
    return match.group(1) if match else value.strip().lower()


def normalize_doi(value: str | None) -> str | None:
    if not value:
        return None
    normalized = value.strip().lower()
    normalized = re.sub(r"^https?://doi\.org/", "", normalized)
    normalized = re.sub(r"^doi:\s*", "", normalized)
    return normalized or None


def normalize_external_ids(values: Mapping[str, object] | None) -> dict[str, str]:
    result: dict[str, str] = {}
    for key, value in (values or {}).items():
        if value is None or str(value).strip() == "":
            continue
        text = str(value).strip()
        if key == "arxiv_id":
            text = normalize_arxiv_id(text) or text
        elif key == "doi":
            text = normalize_doi(text) or text
        result[str(key)] = text
    return result


def normalized_title(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def identity_key(external_ids: Mapping[str, str], title: str, authors: Iterable[str], published_at: str) -> str:
    priority = ("arxiv_id", "doi", "openalex_id", "semantic_scholar_id", "huggingface_id")
    for key in priority:
        value = external_ids.get(key)
        if value:
            return f"{key}:{value}"
    author = next(iter(authors), "")
    return "fingerprint:" + "|".join((normalized_title(title), normalized_title(author), published_at[:10]))


def stable_paper_id(external_ids: Mapping[str, str], title: str, authors: Iterable[str], published_at: str) -> str:
    digest = hashlib.sha256(identity_key(external_ids, title, authors, published_at).encode("utf-8")).hexdigest()[:24]
    return f"paper_{digest}"


def fuzzy_identity_score(left_title: str, right_title: str, left_author: str = "", right_author: str = "") -> float:
    title_score = SequenceMatcher(None, normalized_title(left_title), normalized_title(right_title)).ratio()
    if not left_author or not right_author:
        return title_score
    author_score = SequenceMatcher(None, normalized_title(left_author), normalized_title(right_author)).ratio()
    return title_score * 0.8 + author_score * 0.2
