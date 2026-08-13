from __future__ import annotations

import json
from typing import Any, Mapping


def encode_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":"))


def load_json(value: str | None, fallback: Any) -> Any:
    if value is None:
        return fallback
    return json.loads(value)


def merge_nested_json(
    current: Mapping[str, Any],
    incoming: Mapping[str, Any],
) -> dict[str, Any]:
    merged = dict(current)
    for key, value in incoming.items():
        if value is None:
            continue
        existing = merged.get(key)
        if isinstance(existing, Mapping) and isinstance(value, Mapping):
            merged[key] = merge_nested_json(existing, value)
        else:
            merged[key] = value
    return merged
