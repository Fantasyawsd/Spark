from __future__ import annotations

import argparse
import json
import os
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from typing import Mapping

from .api import PaperApiService, create_server
from .dataset import DatasetImporter
from .pipeline import SnapshotStore, SyncRunner
from .models import utc_now
from .sources import (
    ArxivOaiSource,
    decode_arxiv_oai_cursor,
    encode_arxiv_oai_cursor,
    GitHubRepositorySource,
    HuggingFaceDailySource,
    JsonFileSource,
    SemanticScholarBatchSource,
)
from .storage import PaperStore


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Spark paper data platform")
    parser.add_argument("--db", default="data/papers.sqlite3")
    parser.add_argument("--snapshots", default="data/snapshots")
    subparsers = parser.add_subparsers(dest="command", required=True)
    sync = subparsers.add_parser("sync-json")
    sync.add_argument("--source", required=True)
    sync.add_argument("--file", required=True)
    dataset = subparsers.add_parser("import-dataset")
    dataset.add_argument("--arxiv-file", required=True)
    dataset.add_argument("--venue-dir")
    dataset.add_argument("--openalex-file")
    dataset.add_argument("--batch-size", type=int, default=500)
    dataset.add_argument("--max-records", type=int)
    dataset.add_argument("--progress-every", type=int, default=10000)
    external = subparsers.add_parser("sync-external")
    external.add_argument("--hf-days", type=int, default=7)
    external.add_argument("--hf-max-pages", type=int, default=10)
    external.add_argument("--semantic-scholar-limit", type=int, default=500)
    external.add_argument("--semantic-scholar-stale-hours", type=int, default=168)
    external.add_argument("--github-limit", type=int, default=50)
    external.add_argument("--github-stale-hours", type=int, default=24)
    external.add_argument("--skip-hf", action="store_true")
    external.add_argument("--skip-semantic-scholar", action="store_true")
    external.add_argument("--skip-github", action="store_true")
    arxiv_oai = subparsers.add_parser("sync-arxiv-oai")
    arxiv_oai.add_argument("--from-date", type=_iso_date)
    arxiv_oai.add_argument("--until-date", type=_iso_date)
    arxiv_oai.add_argument("--max-pages", type=int, default=100)
    arxiv_oai.add_argument("--timeout", type=float, default=30.0)
    arxiv_oai.add_argument("--skip-index-refresh", action="store_true")
    serve = subparsers.add_parser("serve")
    serve.add_argument("--host", default="127.0.0.1")
    serve.add_argument("--port", type=int, default=8000)
    return parser


def _iso_date(value: str) -> str:
    try:
        date.fromisoformat(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("日期必须是 YYYY-MM-DD") from error
    return value


def _arxiv_oai_window(store: PaperStore, from_date: str | None, until_date: str | None, now) -> tuple[str, str]:
    state = store.get_sync_state("arxiv_oai")
    today = now.date()
    resolved_until = until_date or today.isoformat()
    checkpoint = decode_arxiv_oai_cursor(state.get("cursor"))
    if state.get("cursor") and state.get("window_from") and state.get("window_until"):
        resolved_from = str(state["window_from"])
        resolved_until = str(state["window_until"])
    elif state.get("cursor") and checkpoint.get("from_date") and checkpoint.get("until_date"):
        resolved_from = str(checkpoint["from_date"])
        resolved_until = str(checkpoint["until_date"])
    else:
        if from_date:
            resolved_from = from_date
        elif state.get("completed_through"):
            resolved_from = str(state["completed_through"])[:10]
        else:
            latest_arxiv_update = store.latest_source_update("arxiv")
            resolved_from = (
                latest_arxiv_update.date().isoformat()
                if latest_arxiv_update is not None
                else (today - timedelta(days=1)).isoformat()
            )
    if date.fromisoformat(resolved_until) > today:
        raise ValueError(
            f"arXiv OAI 增量窗口无效：until={resolved_until} 晚于当前日期 {today.isoformat()}"
        )
    if resolved_from > resolved_until:
        raise ValueError(f"arXiv OAI 增量窗口无效：from={resolved_from} after until={resolved_until}")
    return resolved_from, resolved_until


def _ensure_arxiv_oai_checkpoint(
    store: PaperStore,
    from_date: str,
    until_date: str,
    now: datetime,
) -> dict[str, str | None]:
    state = store.get_sync_state("arxiv_oai")
    if state.get("cursor"):
        return state
    store.set_sync_state(
        "arxiv_oai",
        state.get("etag"),
        encode_arxiv_oai_cursor(from_date, until_date, ""),
        state.get("last_snapshot_path"),
        now,
        window_from=from_date,
        window_until=until_date,
        mark_success=False,
    )
    return store.get_sync_state("arxiv_oai")


def _failed_syncs(report: Mapping[str, object]) -> list[str]:
    return [
        name
        for name, result in report.items()
        if isinstance(result, Mapping) and result.get("status") == "failed"
    ]


def main() -> None:
    args = build_parser().parse_args()
    store = PaperStore(args.db)
    try:
        if args.command == "sync-json":
            result = SyncRunner(store, SnapshotStore(args.snapshots)).sync(JsonFileSource(args.source, args.file))
            print(json.dumps(result, ensure_ascii=True, indent=2))
            return
        if args.command == "import-dataset":
            last_progress: dict[str, int] = {}

            def report_progress(item: dict) -> None:
                key = str(item["dataset_key"])
                line_number = int(item["line_number"])
                previous = last_progress.get(key, 0)
                if line_number - previous >= max(1, args.progress_every):
                    print(json.dumps({"progress": item}, ensure_ascii=True), flush=True)
                    last_progress[key] = line_number

            importer = DatasetImporter(
                store,
                batch_size=args.batch_size,
                progress=report_progress,
            )
            report = {"arxiv": importer.import_arxiv(args.arxiv_file, max_records=args.max_records)}
            if report["arxiv"].get("status") == "completed":
                if args.venue_dir:
                    report["venues"] = importer.import_venues(args.venue_dir)
                if args.openalex_file:
                    report["openalex"] = importer.import_openalex(args.openalex_file)
                if not store.indexes_ready():
                    store.refresh_indexes()
                    report["indexes_refreshed"] = True
                else:
                    report["indexes_refreshed"] = False
            report["paper_count"] = store.count()
            report["database"] = str(Path(args.db).resolve())
            print(json.dumps(report, ensure_ascii=True, indent=2))
            return
        if args.command == "sync-external":
            now = utc_now()
            runner = SyncRunner(store, SnapshotStore(args.snapshots))
            report: dict[str, object] = {}
            if not args.skip_hf:
                hf_days = max(1, min(int(args.hf_days), 31))
                dates = tuple(
                    (now - timedelta(days=offset)).date().isoformat()
                    for offset in range(hf_days)
                )
                report["huggingface"] = runner.sync(
                    HuggingFaceDailySource(
                        dates=dates,
                        max_pages=max(1, min(int(args.hf_max_pages), 20)),
                    ),
                    refresh_indexes=False,
                )
            if not args.skip_semantic_scholar:
                semantic_ids = store.semantic_scholar_candidates(
                    limit=max(1, int(args.semantic_scholar_limit)),
                    stale_before=now
                    - timedelta(hours=max(1, int(args.semantic_scholar_stale_hours))),
                )
                report["semantic_scholar_requested"] = len(semantic_ids)
                if semantic_ids:
                    report["semantic_scholar"] = runner.sync(
                        SemanticScholarBatchSource(
                            tuple(semantic_ids),
                            api_key=os.environ.get("SEMANTIC_SCHOLAR_API_KEY"),
                        ),
                        refresh_indexes=False,
                    )
            if not args.skip_github:
                github_candidates = store.github_candidates(
                    limit=max(1, int(args.github_limit)),
                    stale_before=now
                    - timedelta(hours=max(1, int(args.github_stale_hours))),
                )
                report["github_requested"] = len(github_candidates)
                if github_candidates:
                    report["github"] = runner.sync(
                        GitHubRepositorySource(
                            tuple(github_candidates),
                            token=os.environ.get("GITHUB_TOKEN"),
                        ),
                        refresh_indexes=False,
                    )
            failed_sources = _failed_syncs(report)
            if failed_sources:
                report["indexes_refreshed"] = False
                report["failed_sources"] = failed_sources
            else:
                store.refresh_indexes(now)
                report["indexes_refreshed"] = True
            report["paper_count"] = store.count()
            report["database"] = str(Path(args.db).resolve())
            print(json.dumps(report, ensure_ascii=True, indent=2))
            if failed_sources:
                raise SystemExit(1)
            return
        if args.command == "sync-arxiv-oai":
            now = utc_now()
            from_date, until_date = _arxiv_oai_window(store, args.from_date, args.until_date, now)
            state = _ensure_arxiv_oai_checkpoint(store, from_date, until_date, now)
            runner = SyncRunner(store, SnapshotStore(args.snapshots))
            source = ArxivOaiSource(
                from_date=from_date,
                until_date=until_date,
                timeout=max(1.0, float(args.timeout)),
            )
            report = runner.sync_paginated(
                source,
                state_name="arxiv_oai",
                max_pages=max(1, int(args.max_pages)),
                admitted_only=True,
                refresh_indexes=not args.skip_index_refresh,
                completion_watermark=datetime.combine(
                    date.fromisoformat(until_date),
                    time.min,
                    tzinfo=timezone.utc,
                ),
                window_key=f"{from_date}-to-{until_date}",
            )
            report.update(
                {
                    "from_date": from_date,
                    "until_date": until_date,
                    "paper_count": store.count(),
                    "database": str(Path(args.db).resolve()),
                }
            )
            print(json.dumps(report, ensure_ascii=True, indent=2))
            if report["status"] != "success":
                raise SystemExit(1)
            return
        if args.command == "serve":
            server = create_server(PaperApiService(store), args.host, args.port)
            print(f"Spark Paper API listening on http://{args.host}:{args.port}")
            server.serve_forever()
    finally:
        store.close()


if __name__ == "__main__":
    main()
