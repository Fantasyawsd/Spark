from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Mapping, Protocol

from .models import FetchResult, parse_datetime, utc_now


class SourceError(RuntimeError):
    pass


class RetryableSourceError(SourceError):
    pass


class SourceAdapter(Protocol):
    name: str

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        ...


@dataclass(frozen=True)
class StaticSource:
    name: str
    records: tuple[Mapping[str, Any], ...]
    snapshot_key: str = "fixture"

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        return FetchResult(
            source=self.name,
            records=self.records,
            raw_payload={"source": self.name, "records": list(self.records)},
            fetched_at=utc_now(),
            cursor=self.snapshot_key,
            etag=f'"{self.snapshot_key}"',
            snapshot_key=self.snapshot_key,
            not_modified=etag == f'"{self.snapshot_key}"',
        )


class JsonFileSource:
    def __init__(self, name: str, path: str, snapshot_key: str | None = None) -> None:
        self.name = name
        self.path = path
        self.snapshot_key = snapshot_key or path

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        with open(self.path, encoding="utf-8") as handle:
            payload = json.load(handle)
        records = payload if isinstance(payload, list) else payload.get("records", payload.get("results", payload.get("data", payload.get("items", []))))
        if not isinstance(records, list):
            raise SourceError(f"{self.path} does not contain a record list")
        return FetchResult(
            source=self.name,
            records=tuple(item for item in records if isinstance(item, Mapping)),
            raw_payload=payload,
            fetched_at=utc_now(),
            cursor=self.snapshot_key,
            etag=f'"{self.snapshot_key}"',
            snapshot_key=self.snapshot_key,
            not_modified=etag == f'"{self.snapshot_key}"',
        )


class JsonLinesFileSource(JsonFileSource):
    """Imports a local arXiv-style JSONL dump without loading it as one object."""

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        with open(self.path, encoding="utf-8") as handle:
            records = tuple(json.loads(line) for line in handle if line.strip())
        return FetchResult(
            source=self.name,
            records=tuple(item for item in records if isinstance(item, Mapping)),
            raw_payload={"path": self.path, "records": list(records)},
            fetched_at=utc_now(),
            cursor=self.snapshot_key,
            etag=f'"{self.snapshot_key}"',
            snapshot_key=self.snapshot_key,
            not_modified=etag == f'"{self.snapshot_key}"',
        )


class HttpJsonSource:
    def __init__(self, name: str, endpoint: str, *, timeout: float = 20.0, query: Mapping[str, str] | None = None, max_retries: int = 3, retry_backoff: float = 1.0) -> None:
        self.name = name
        self.endpoint = endpoint
        self.timeout = timeout
        self.query = dict(query or {})
        self.max_retries = max(0, max_retries)
        self.retry_backoff = max(0.0, retry_backoff)

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        query = dict(self.query)
        if cursor:
            query["cursor"] = cursor
        url = self.endpoint
        if query:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(query)
        request = urllib.request.Request(url, headers={"Accept": "application/json", **({"If-None-Match": etag} if etag else {})})
        for attempt in range(self.max_retries + 1):
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    status = int(response.status)
                    if status == 304:
                        return FetchResult(self.name, (), None, utc_now(), cursor=cursor, etag=etag, not_modified=True)
                    body = response.read()
                    payload = json.loads(body.decode("utf-8"))
                    response_etag = response.headers.get("ETag")
                    break
            except urllib.error.HTTPError as error:
                if error.code == 304:
                    return FetchResult(self.name, (), None, utc_now(), cursor=cursor, etag=etag, not_modified=True)
                if error.code == 429 or 500 <= error.code < 600:
                    if attempt < self.max_retries:
                        time.sleep(_retry_delay(error.headers, attempt, self.retry_backoff))
                        continue
                    raise RetryableSourceError(f"{self.name} returned HTTP {error.code}") from error
                raise SourceError(f"{self.name} returned HTTP {error.code}") from error
            except (OSError, json.JSONDecodeError) as error:
                if attempt < self.max_retries:
                    time.sleep(self.retry_backoff * (2**attempt))
                    continue
                raise RetryableSourceError(f"{self.name} fetch failed: {error}") from error
        records = payload if isinstance(payload, list) else payload.get("records", payload.get("results", payload.get("data", payload.get("items", []))))
        if not isinstance(records, list):
            raise SourceError(f"{self.name} response does not contain records")
        raw_payload = {"request": {"url": self.endpoint, "query": query}, "response": payload}
        return FetchResult(self.name, tuple(item for item in records if isinstance(item, Mapping)), raw_payload, utc_now(), cursor=cursor, etag=response_etag)


class HuggingFaceDailySource(HttpJsonSource):
    def __init__(self, date: str | None = None, *, dates: tuple[str, ...] | None = None, max_pages: int = 10, **kwargs: Any) -> None:
        query = dict(kwargs.pop("query", {}) or {})
        if date:
            query["date"] = date
        query.setdefault("limit", "100")
        query.setdefault("sort", "publishedAt")
        self.dates = dates or ((date,) if date else (None,))
        self.max_pages = max(1, max_pages)
        super().__init__("huggingface", kwargs.pop("endpoint", "https://huggingface.co/api/daily_papers"), query=query, **kwargs)

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        normalized: list[Mapping[str, Any]] = []
        responses: list[Any] = []
        requests: list[Mapping[str, Any]] = []
        last_result: FetchResult | None = None
        for requested_date in self.dates:
            for page in range(self.max_pages):
                page_query = dict(self.query)
                if requested_date:
                    page_query["date"] = requested_date
                page_query["p"] = str(page)
                page_source = HttpJsonSource(self.name, self.endpoint, timeout=self.timeout, query=page_query, max_retries=self.max_retries, retry_backoff=self.retry_backoff)
                result = page_source.fetch(etag=etag if page == 0 else None)
                last_result = result
                responses.append(result.raw_payload)
                requests.append({"date": requested_date, "page": page, "query": page_query})
                for item in result.records:
                    paper = item.get("paper") if isinstance(item.get("paper"), Mapping) else item
                    normalized.append(_normalize_huggingface_record(item, paper))
                if len(result.records) < int(page_query.get("limit", "100")):
                    break
        if last_result is None:
            return FetchResult(self.name, (), {"requests": requests, "responses": responses}, utc_now(), cursor=cursor, etag=etag)
        return FetchResult(self.name, tuple(normalized), {"requests": requests, "responses": responses}, last_result.fetched_at, cursor=cursor, etag=last_result.etag, snapshot_key=(requested_date or "all") if self.dates else None, not_modified=last_result.not_modified and not normalized)


class OpenAlexSource(HttpJsonSource):
    """Maps OpenAlex Works into enrichment observations."""

    def __init__(self, endpoint: str = "https://api.openalex.org/works", **kwargs: Any) -> None:
        super().__init__("openalex", endpoint, **kwargs)

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        result = super().fetch(etag=etag, cursor=cursor)
        records = tuple(_normalize_openalex_record(item) for item in result.records)
        return FetchResult(result.source, records, result.raw_payload, result.fetched_at, result.cursor, result.etag, result.snapshot_key, result.not_modified)


class SemanticScholarSource(HttpJsonSource):
    """Maps Semantic Scholar graph records into enrichment observations."""

    def __init__(self, endpoint: str = "https://api.semanticscholar.org/graph/v1/paper/search", **kwargs: Any) -> None:
        super().__init__("semantic_scholar", endpoint, **kwargs)

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        result = super().fetch(etag=etag, cursor=cursor)
        records = tuple(_normalize_semantic_scholar_record(item) for item in result.records)
        return FetchResult(result.source, records, result.raw_payload, result.fetched_at, result.cursor, result.etag, result.snapshot_key, result.not_modified)


class GitHubEnrichmentSource(HttpJsonSource):
    """Maps pre-matched GitHub repository observations into enrichment records.

    A repository is accepted only when its payload contains a paper identity
    such as arXiv ID or DOI. Repository search and paper matching remain an
    offline curation step, so an unlinked repository cannot become a paper.
    """

    def __init__(self, endpoint: str, **kwargs: Any) -> None:
        super().__init__("github", endpoint, **kwargs)

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        result = super().fetch(etag=etag, cursor=cursor)
        records = tuple(
            mapped for mapped in (_normalize_github_record(item) for item in result.records)
            if any(mapped.get(key) for key in ("arxiv_id", "doi", "openalex_id", "semantic_scholar_id"))
        )
        return FetchResult(result.source, records, result.raw_payload, result.fetched_at, result.cursor, result.etag, result.snapshot_key, result.not_modified)


class ArxivAtomSource:
    name = "arxiv"

    def __init__(self, endpoint: str = "https://export.arxiv.org/api/query", *, search_query: str = "cat:cs.AI", max_results: int = 100, timeout: float = 30.0) -> None:
        self.endpoint = endpoint
        self.search_query = search_query
        self.max_results = max_results
        self.timeout = timeout

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        params = urllib.parse.urlencode({"search_query": self.search_query, "start": cursor or "0", "max_results": self.max_results})
        request = urllib.request.Request(f"{self.endpoint}?{params}", headers={"Accept": "application/atom+xml", **({"If-None-Match": etag} if etag else {})})
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                body = response.read()
                response_etag = response.headers.get("ETag")
        except urllib.error.HTTPError as error:
            if error.code == 304:
                return FetchResult(self.name, (), None, utc_now(), cursor=cursor, etag=etag, not_modified=True)
            if error.code == 429 or 500 <= error.code < 600:
                raise RetryableSourceError(f"arxiv returned HTTP {error.code}") from error
            raise SourceError(f"arxiv returned HTTP {error.code}") from error
        except OSError as error:
            raise RetryableSourceError(f"arxiv fetch failed: {error}") from error
        records = tuple(_parse_arxiv_entry(entry) for entry in ET.fromstring(body).findall("{http://www.w3.org/2005/Atom}entry"))
        next_cursor = str((int(cursor or "0") + len(records))) if records else cursor
        return FetchResult(self.name, records, body.decode("utf-8"), utc_now(), next_cursor, response_etag)


class ArxivOaiSource:
    """Imports historical arXiv metadata through the OAI-PMH ListRecords API."""

    name = "arxiv"

    def __init__(self, endpoint: str = "https://export.arxiv.org/oai2", *, set_name: str = "", timeout: float = 30.0) -> None:
        self.endpoint = endpoint
        self.set_name = set_name
        self.timeout = timeout

    def fetch(self, *, etag: str | None = None, cursor: str | None = None) -> FetchResult:
        params = {"verb": "ListRecords", "metadataPrefix": "arXiv"}
        if self.set_name:
            params["set"] = self.set_name
        if cursor:
            params = {"verb": "ListRecords", "resumptionToken": cursor}
        request = urllib.request.Request(self.endpoint + "?" + urllib.parse.urlencode(params), headers={"Accept": "application/xml"})
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                body = response.read()
        except urllib.error.HTTPError as error:
            if error.code == 429 or 500 <= error.code < 600:
                raise RetryableSourceError(f"arxiv OAI returned HTTP {error.code}") from error
            raise SourceError(f"arxiv OAI returned HTTP {error.code}") from error
        except OSError as error:
            raise RetryableSourceError(f"arxiv OAI fetch failed: {error}") from error
        root = ET.fromstring(body)
        records = tuple(_parse_oai_record(record) for record in root.findall(".//{http://www.openarchives.org/OAI/2.0/}record"))
        token = root.findtext(".//{http://www.openarchives.org/OAI/2.0/}resumptionToken") or None
        return FetchResult(self.name, records, body.decode("utf-8"), utc_now(), cursor=token, etag=None)


def _normalize_huggingface_record(item: Mapping[str, Any], paper: Mapping[str, Any]) -> dict[str, Any]:
    authors = paper.get("authors") or item.get("authors") or []
    return {
        "external_id": str(paper.get("id") or paper.get("arxiv_id") or item.get("id") or ""),
        "id": paper.get("id") or paper.get("arxiv_id") or item.get("id"),
        "title": paper.get("title") or item.get("title"),
        "abstract": paper.get("summary") or paper.get("abstract") or item.get("summary"),
        "authors": authors,
        "published_at": paper.get("publishedAt") or paper.get("published_at") or item.get("publishedAt") or item.get("published_at"),
        "updated_at": paper.get("updatedAt") or paper.get("updated_at"),
        "arxiv_id": paper.get("arxiv_id") or paper.get("id"),
        "subjects": paper.get("categories") or item.get("categories") or (),
        "heat": _first_present(item, "upvotes", "heat") if _first_present(item, "upvotes", "heat") is not None else paper.get("upvotes"),
        "metadata": {"hf_rank": _first_present(item, "rank") if _first_present(item, "rank") is not None else paper.get("rank")},
    }


def _normalize_openalex_record(item: Mapping[str, Any]) -> dict[str, Any]:
    openalex_id = str(item.get("id") or "").rstrip("/").rsplit("/", 1)[-1] or None
    primary_location = item.get("primary_location") or {}
    source = primary_location.get("source") if isinstance(primary_location, Mapping) else {}
    authorships = item.get("authorships") or []
    topics = item.get("topics") or item.get("concepts") or []
    signals = {
        "openalex": {
            "citation_count": item.get("cited_by_count"),
            "fwci": item.get("fwci"),
            "citation_normalized_percentile": item.get("citation_normalized_percentile"),
            "topics": topics,
        }
    }
    return {
        "external_id": openalex_id or str(item.get("doi") or item.get("title") or ""),
        "openalex_id": openalex_id,
        "doi": item.get("doi"),
        "title": item.get("display_name") or item.get("title"),
        "abstract": _openalex_abstract(item.get("abstract_inverted_index")),
        "authors": [{"name": (entry.get("author") or {}).get("display_name")} for entry in authorships if isinstance(entry, Mapping)],
        "published_at": item.get("publication_date") or (f"{item['publication_year']}-01-01T00:00:00Z" if item.get("publication_year") else None),
        "updated_at": item.get("updated_date"),
        "subjects": (),
        "signals": signals,
        "metadata": {
            "venue_name": (source or {}).get("display_name") if isinstance(source, Mapping) else None,
            "venue_url": (source or {}).get("homepage_url") if isinstance(source, Mapping) else None,
        },
    }


def _normalize_semantic_scholar_record(item: Mapping[str, Any]) -> dict[str, Any]:
    external = item.get("externalIds") or {}
    paper_id = item.get("paperId")
    year = item.get("year")
    published_at = item.get("publicationDate") or (f"{year}-01-01T00:00:00Z" if year else None)
    return {
        "external_id": str(paper_id or external.get("ArXiv") or external.get("DOI") or item.get("title") or ""),
        "semantic_scholar_id": paper_id,
        "arxiv_id": external.get("ArXiv"),
        "doi": external.get("DOI"),
        "title": item.get("title"),
        "abstract": item.get("abstract"),
        "authors": item.get("authors"),
        "published_at": published_at,
        "subjects": item.get("fieldsOfStudy") or (),
        "signals": {
            "semantic_scholar": {
                "citation_count": item.get("citationCount"),
                "influential_citation_count": item.get("influentialCitationCount"),
                "reference_count": item.get("referenceCount"),
            }
        },
    }


def _normalize_github_record(item: Mapping[str, Any]) -> dict[str, Any]:
    identity = item.get("paper") if isinstance(item.get("paper"), Mapping) else item
    repository = item.get("repository") if isinstance(item.get("repository"), Mapping) else item
    return {
        "external_id": str(repository.get("full_name") or repository.get("html_url") or ""),
        "arxiv_id": identity.get("arxiv_id"),
        "doi": identity.get("doi"),
        "openalex_id": identity.get("openalex_id"),
        "semantic_scholar_id": identity.get("semantic_scholar_id"),
        "github_url": repository.get("html_url") or repository.get("url"),
        "title": identity.get("title") or repository.get("name"),
        "abstract": identity.get("abstract"),
        "authors": identity.get("authors") or (),
        "published_at": identity.get("published_at") or repository.get("created_at"),
        "subjects": identity.get("subjects") or (),
        "signals": {
            "github": {
                "url": repository.get("html_url") or repository.get("url"),
                "stars": _first_present(repository, "stargazers_count", "stars"),
                "forks": _first_present(repository, "forks_count", "forks"),
                "last_updated_at": repository.get("updated_at"),
                "stars_updated_at": item.get("stars_updated_at"),
                "star_velocity": item.get("star_velocity"),
            }
        },
        "metadata": {"github_url": repository.get("html_url") or repository.get("url")},
    }


def _first_present(value: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        if value.get(key) is not None:
            return value[key]
    return None


def _openalex_abstract(value: Any) -> str | None:
    if not isinstance(value, Mapping):
        return value if isinstance(value, str) else None
    words: list[tuple[int, str]] = []
    for word, positions in value.items():
        for position in positions or []:
            words.append((int(position), str(word)))
    if not words:
        return None
    return " ".join(word for _, word in sorted(words))


def _retry_delay(headers: Mapping[str, str], attempt: int, base: float) -> float:
    retry_after = headers.get("Retry-After")
    try:
        return max(0.0, min(float(retry_after), 60.0)) if retry_after is not None else base * (2**attempt)
    except ValueError:
        return base * (2**attempt)


def _parse_oai_record(record: ET.Element) -> dict[str, Any]:
    ns = "{http://arxiv.org/OAI/arXiv/}"
    metadata = record.find(".//" + ns + "arXiv")
    if metadata is None:
        return {}
    text = lambda tag: (metadata.findtext(ns + tag) or "").strip()
    authors = []
    for author in metadata.findall(ns + "authors/" + ns + "author"):
        name = " ".join(filter(None, (author.findtext(ns + "forenames"), author.findtext(ns + "keyname"))))
        if name:
            authors.append({"name": name})
    arxiv_id = text("id")
    categories = text("categories").split()
    return {
        "external_id": arxiv_id,
        "arxiv_id": arxiv_id,
        "title": text("title"),
        "abstract": text("abstract"),
        "authors": authors,
        "published_at": text("created"),
        "updated_at": text("updated"),
        "subjects": categories,
        "doi": text("doi") or None,
        "metadata": {"journal_ref": text("journal-ref") or None},
    }


def _parse_arxiv_entry(entry: ET.Element) -> dict[str, Any]:
    ns = "{http://www.w3.org/2005/Atom}"
    text = lambda tag: (entry.findtext(ns + tag) or "").strip()
    authors = [{"name": node.findtext(ns + "name")} for node in entry.findall(ns + "author")]
    categories = [node.attrib.get("term", "") for node in entry.findall(ns + "category")]
    links = {node.attrib.get("rel"): node.attrib.get("href") for node in entry.findall(ns + "link")}
    arxiv_id = text("id").rsplit("/", 1)[-1]
    return {
        "external_id": arxiv_id,
        "arxiv_id": arxiv_id,
        "title": text("title"),
        "abstract": text("summary"),
        "authors": authors,
        "published_at": text("published"),
        "updated_at": text("updated"),
        "subjects": categories,
        "metadata": {"abs_url": links.get("alternate"), "pdf_url": next((value for rel, value in links.items() if rel == "related"), None)},
    }
