from __future__ import annotations

import base64
import json
import math
from dataclasses import dataclass, field
from typing import Any, Mapping

PROFILE_VERSION = "profile.v1"
MAX_KEYS_PER_DIMENSION = 64
MAX_WEIGHT_ABS = 10.0


@dataclass(frozen=True)
class AnonymousProfile:
    """Anonymized preference profile attached to recommendation requests."""

    version: str = PROFILE_VERSION
    subjects: Mapping[str, float] = field(default_factory=dict)
    keywords: Mapping[str, float] = field(default_factory=dict)
    venues: Mapping[str, float] = field(default_factory=dict)

    def to_payload(self) -> dict[str, Any]:
        return {
            "profile_version": self.version,
            "subjects": dict(self.subjects),
            "keywords": dict(self.keywords),
            "venues": dict(self.venues),
        }


def parse_anonymous_profile(payload: Any) -> AnonymousProfile | None:
    """Parse and validate a profile payload; returns None when invalid.

    The version must be known, every dimension holds at most
    MAX_KEYS_PER_DIMENSION entries, and weights must be finite numbers
    within [-MAX_WEIGHT_ABS, MAX_WEIGHT_ABS]. Unknown versions are rejected
    so clients never silently rely on a server that ignores their signals.
    """
    if not isinstance(payload, Mapping):
        return None
    if payload.get("profile_version") != PROFILE_VERSION:
        return None
    dimensions: dict[str, Mapping[str, float]] = {}
    for name in ("subjects", "keywords", "venues"):
        raw = payload.get(name, {})
        if not isinstance(raw, Mapping):
            return None
        weights: dict[str, float] = {}
        for key, value in raw.items():
            normalized = str(key).strip()
            if not normalized:
                return None
            weight = _number(value)
            if weight is None or abs(weight) > MAX_WEIGHT_ABS:
                return None
            weights[normalized] = weight
        if len(weights) > MAX_KEYS_PER_DIMENSION:
            return None
        dimensions[name] = weights
    return AnonymousProfile(
        version=PROFILE_VERSION,
        subjects=dimensions["subjects"],
        keywords=dimensions["keywords"],
        venues=dimensions["venues"],
    )


def encode_anonymous_profile(profile: AnonymousProfile) -> str:
    raw = json.dumps(profile.to_payload(), ensure_ascii=False, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def decode_anonymous_profile(value: str) -> AnonymousProfile | None:
    try:
        padding = "=" * (-len(value) % 4)
        raw = base64.urlsafe_b64decode((value + padding).encode())
        return parse_anonymous_profile(json.loads(raw.decode()))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
        return None


def _number(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    return parsed if math.isfinite(parsed) else None
