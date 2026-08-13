from __future__ import annotations

import base64
import json
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlsplit
from typing import Any, Iterable, Mapping

from . import API_SCHEMA_VERSION, SCORE_VERSION
from .diagnostics import ServerDiagnosticOperation, report_unexpected
from .dto import paper_to_api, recommendation_to_api
from .models import PaperRecord, parse_datetime
from .ports import PaperRepository
from .recommendation import RecommendationEngine


INTERNAL_ERROR_MESSAGE = "Paper service is temporarily unavailable."


def encode_cursor(cursor: tuple[str, str] | None) -> str | None:
    if cursor is None:
        return None
    value = json.dumps({"published_at": cursor[0], "paper_id": cursor[1]}, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(value).decode().rstrip("=")


def decode_cursor(value: str | None) -> tuple[str, str] | None:
    if not value:
        return None
    try:
        padding = "=" * (-len(value) % 4)
        payload = json.loads(base64.urlsafe_b64decode((value + padding).encode()).decode())
        return str(payload["published_at"]), str(payload["paper_id"])
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        raise ValueError("invalid cursor")


class PaperApiService:
    def __init__(self, store: PaperRepository, recommendation: RecommendationEngine | None = None) -> None:
        self.store = store
        self.recommendation = recommendation or RecommendationEngine(store)

    def health(self) -> dict[str, Any]:
        return {"status": "ok", "schema_version": API_SCHEMA_VERSION, "paper_count": self.store.count()}

    def paper(self, paper_id: str) -> dict[str, Any] | None:
        paper = self.store.get(paper_id)
        return paper_to_api(paper) if paper else None

    def latest(self, query: Mapping[str, list[str]]) -> dict[str, Any]:
        limit = _limit(query)
        items, next_cursor = self.store.list_papers(
            limit=limit,
            cursor=decode_cursor(_first(query, "cursor")),
            sort="latest",
            sources=("arxiv", "huggingface"),
        )
        return _feed_response("latest", items, next_cursor=next_cursor)

    def subject(self, subject: str, query: Mapping[str, list[str]]) -> dict[str, Any]:
        sort = _first(query, "sort") or "latest"
        if sort not in {"latest", "quality"}:
            raise ValueError("sort must be latest or quality")
        items, next_cursor = self.store.list_papers(
            limit=_limit(query),
            cursor=decode_cursor(_first(query, "cursor")),
            subject=subject,
            venue=None,
            from_date=_query_date(query, "from"),
            to_date=_query_date(query, "to"),
            sort=sort,
        )
        return _feed_response("subject", items, next_cursor=next_cursor, filters={"subject": subject, "sort": sort})

    def conference(self, venue: str, query: Mapping[str, list[str]]) -> dict[str, Any]:
        sort = _first(query, "sort") or "latest"
        if sort not in {"latest", "quality"}:
            raise ValueError("sort must be latest or quality")
        year_value = _first(query, "year")
        try:
            year = int(year_value) if year_value else None
        except ValueError as error:
            raise ValueError("year must be an integer") from error
        items, next_cursor = self.store.list_papers(
            limit=_limit(query),
            cursor=decode_cursor(_first(query, "cursor")),
            venue=venue,
            venue_year=year,
            track=_first(query, "track"),
            sort=sort,
        )
        return _feed_response("conference", items, next_cursor=next_cursor, filters={"venue": venue, "year": year, "track": _first(query, "track"), "sort": sort})

    def following(self, query: Mapping[str, list[str]]) -> dict[str, Any]:
        authors = {item.strip().lower() for item in (_first(query, "authors") or "").split(",") if item.strip()}
        subjects = {item.strip().lower() for item in (_first(query, "subjects") or "").split(",") if item.strip()}
        venues = {item.strip().lower() for item in (_first(query, "venues") or "").split(",") if item.strip()}
        if not (authors or subjects or venues):
            raise ValueError("following requires authors, subjects, or venues")
        items, next_cursor = self.store.list_following(
            authors=authors,
            subjects=subjects,
            venues=venues,
            limit=_limit(query),
            cursor=decode_cursor(_first(query, "cursor")),
        )
        return _feed_response("following", items, next_cursor=next_cursor, filters={"authors": sorted(authors), "subjects": sorted(subjects), "venues": sorted(venues)})

    def recommended(self, query: Mapping[str, list[str]]) -> dict[str, Any]:
        read_ids = [value for value in (_first(query, "read_ids") or "").split(",") if value]
        seed_value = _first(query, "seed")
        seed = int(seed_value) if seed_value else None
        batch_id, items = self.recommendation.generate(limit=_limit(query), read_ids=read_ids, seed=seed)
        return {
            "schema_version": API_SCHEMA_VERSION,
            "score_version": SCORE_VERSION,
            "channel": "recommended",
            "batch_id": batch_id,
            "items": [recommendation_to_api(item) for item in items],
            "next_cursor": None,
        }


def _feed_response(channel: str, papers: Iterable[PaperRecord], *, next_cursor: tuple[str, str] | None, filters: Mapping[str, Any] | None = None) -> dict[str, Any]:
    return {
        "schema_version": API_SCHEMA_VERSION,
        "channel": channel,
        "items": [paper_to_api(paper) for paper in papers],
        "next_cursor": encode_cursor(next_cursor),
        "filters": dict(filters or {}),
    }


def _first(query: Mapping[str, list[str]], key: str) -> str | None:
    values = query.get(key)
    return values[0] if values else None


def _limit(query: Mapping[str, list[str]]) -> int:
    value = _first(query, "limit") or "20"
    try:
        return max(1, min(int(value), 100))
    except ValueError as error:
        raise ValueError("limit must be an integer") from error


def _query_date(query: Mapping[str, list[str]], key: str) -> datetime | None:
    value = _first(query, key)
    if value is None:
        return None
    parsed = parse_datetime(value)
    if parsed is None:
        raise ValueError(f"{key} must be an ISO-8601 date")
    return parsed


class PaperRequestHandler(BaseHTTPRequestHandler):
    service: PaperApiService

    def do_GET(self) -> None:  # noqa: N802
        try:
            parsed = urlsplit(self.path)
            query = parse_qs(parsed.query, keep_blank_values=True)
            payload, status = self._dispatch(parsed.path, query)
        except ValueError as error:
            payload, status = {"error": "invalid_request", "message": str(error)}, HTTPStatus.BAD_REQUEST
        except Exception as error:
            payload, status = _internal_error_response(error)
        try:
            body = json.dumps(payload, ensure_ascii=True, separators=(",", ":")).encode("utf-8")
        except Exception as error:
            payload, status = _internal_error_response(error)
            body = json.dumps(payload, ensure_ascii=True, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store" if status >= 400 else "public, max-age=30")
        self.end_headers()
        self.wfile.write(body)

    def _dispatch(self, path: str, query: Mapping[str, list[str]]) -> tuple[dict[str, Any], HTTPStatus]:
        parts = [unquote(part) for part in path.split("/") if part]
        if parts == ["api", "v1", "health"]:
            return self.service.health(), HTTPStatus.OK
        if len(parts) == 4 and parts[:3] == ["api", "v1", "papers"]:
            payload = self.service.paper(parts[3])
            return ({"error": "not_found"}, HTTPStatus.NOT_FOUND) if payload is None else (payload, HTTPStatus.OK)
        if parts == ["api", "v1", "channels", "latest"]:
            return self.service.latest(query), HTTPStatus.OK
        if len(parts) == 5 and parts[:4] == ["api", "v1", "channels", "subject"]:
            return self.service.subject(parts[4], query), HTTPStatus.OK
        if len(parts) == 5 and parts[:4] == ["api", "v1", "channels", "conference"]:
            return self.service.conference(parts[4], query), HTTPStatus.OK
        if parts == ["api", "v1", "channels", "following"]:
            return self.service.following(query), HTTPStatus.OK
        if parts in (["api", "v1", "channels", "recommended"], ["api", "v1", "feed", "recommended"]):
            return self.service.recommended(query), HTTPStatus.OK
        return {"error": "not_found"}, HTTPStatus.NOT_FOUND

    def log_message(self, format: str, *args: Any) -> None:
        return


def _internal_error_response(error: Exception) -> tuple[dict[str, str], HTTPStatus]:
    report_unexpected(ServerDiagnosticOperation.HTTP_REQUEST, error)
    return {
        "error": "internal_error",
        "message": INTERNAL_ERROR_MESSAGE,
    }, HTTPStatus.INTERNAL_SERVER_ERROR


def create_server(service: PaperApiService, host: str = "127.0.0.1", port: int = 8000) -> ThreadingHTTPServer:
    handler = type("SparkPaperRequestHandler", (PaperRequestHandler,), {"service": service})
    return ThreadingHTTPServer((host, port), handler)
