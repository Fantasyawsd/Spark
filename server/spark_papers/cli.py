from __future__ import annotations

import argparse
import json
from pathlib import Path

from .api import PaperApiService, create_server
from .dataset import DatasetImporter
from .pipeline import SnapshotStore, SyncRunner
from .sources import JsonFileSource
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
    serve = subparsers.add_parser("serve")
    serve.add_argument("--host", default="127.0.0.1")
    serve.add_argument("--port", type=int, default=8000)
    return parser


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
        if args.command == "serve":
            server = create_server(PaperApiService(store), args.host, args.port)
            print(f"Spark Paper API listening on http://{args.host}:{args.port}")
            server.serve_forever()
    finally:
        store.close()


if __name__ == "__main__":
    main()
