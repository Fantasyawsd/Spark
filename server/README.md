# Spark Paper Platform

This directory contains the Phase 1 paper data pipeline and Phase 2 read-only
Feed API. It is intentionally independent from the Flutter client while the
data platform is being validated.

## Quick start

The implementation uses only the Python standard library and SQLite.

```powershell
$env:PYTHONPATH = (Resolve-Path server).Path
python -m unittest discover -s server/tests -v
python -m spark_papers.cli --db data/papers.sqlite3 --snapshots data/snapshots sync-json --source arxiv --file fixture.json
python -m spark_papers.cli --db data/papers.sqlite3 serve --port 8000
```

To deploy the local Spark arXiv dataset, use the resumable batch importer. The
large `spark-arxiv-ai-full.jsonl` file is the canonical 674,969-paper source;
the `by-year-venue-label` tree is a 99,577-paper conference/label enrichment
subset, not a replacement for the canonical file. OpenAlex enrichment is
matched by arXiv ID and never creates a paper without an existing base record.

```powershell
$dataset = "C:\Users\Fantasy\Desktop\Spark-worktrees\Spark-arxiv-dataset"
$db = "C:\Users\Fantasy\AppData\Local\Spark\paper-api\dataset-v1\papers.sqlite3"
$snapshots = "C:\Users\Fantasy\AppData\Local\Spark\paper-api\dataset-v1\snapshots"
$env:PYTHONPATH = (Resolve-Path server).Path
python -m spark_papers.cli --db $db --snapshots $snapshots import-dataset `
  --arxiv-file "$dataset\spark-arxiv-ai-full.jsonl" `
  --venue-dir "$dataset\by-year-venue-label" `
  --openalex-file "$dataset\openalex-ai-top.jsonl" `
  --batch-size 1000
```

The importer stores byte offsets, line numbers, source signatures, rejected
line excerpts and a short-lived single-run lease in SQLite. Re-running the
same command resumes incomplete work or verifies a completed import. It also
rebuilds Latest, subject/author/venue and bounded recommendation indexes only
when they are stale.

The service exposes:

- `GET /api/v1/health`
- `GET /api/v1/papers/{paper_id}`
- `GET /api/v1/channels/latest?limit=20&cursor=...`
- `GET /api/v1/channels/subject/{subject}?sort=latest|quality&from=...&to=...`
- `GET /api/v1/channels/following?authors=...&subjects=...&venues=...`
- `GET /api/v1/feed/recommended?limit=10&read_ids=...&seed=...`

External adapters write raw responses to the snapshot directory before
normalizing records. A failed or rate-limited sync records a failed snapshot
and keeps the last successful cursor, ETag and raw path. Re-running the same
snapshot is idempotent because source observations use `(source, external_id)`
as their natural key.

The database separates canonical papers, source observations, field
provenance, sync snapshots, match-review candidates and recommendation batch
feature snapshots. Unknown metadata remains `null`; it is never represented by
an empty string or a fake zero.

The canonical record contract is [schema/paper.v1.json](schema/paper.v1.json).
`schema_version` is persisted in every row and in every API DTO so a future
migration can rebuild the database from retained raw snapshots without changing
the Flutter layer.
