from __future__ import annotations

import argparse
import json
from pathlib import Path

from .api import PaperApiService, create_server
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
        if args.command == "serve":
            server = create_server(PaperApiService(store), args.host, args.port)
            print(f"Spark Paper API listening on http://{args.host}:{args.port}")
            server.serve_forever()
    finally:
        store.close()


if __name__ == "__main__":
    main()
