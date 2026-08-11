[CmdletBinding()]
param(
    [string]$Database = (Join-Path $env:LOCALAPPDATA 'Spark\paper-api\dataset-v1\papers.sqlite3'),
    [string]$Snapshots = (Join-Path $env:LOCALAPPDATA 'Spark\paper-api\dataset-v1\snapshots'),
    [ValidateRange(1, 31)]
    [int]$HfDays = 7,
    [ValidateRange(1, 20)]
    [int]$HfMaxPages = 10,
    [ValidateRange(1, 5000)]
    [int]$SemanticScholarLimit = 500,
    [ValidateRange(1, 500)]
    [int]$GithubLimit = 50
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$env:PYTHONPATH = Join-Path $repoRoot 'server'
$python = (Get-Command python -ErrorAction Stop).Source

& $python -m spark_papers.cli `
    --db $Database `
    --snapshots $Snapshots `
    sync-external `
    --hf-days $HfDays `
    --hf-max-pages $HfMaxPages `
    --semantic-scholar-limit $SemanticScholarLimit `
    --github-limit $GithubLimit

if ($LASTEXITCODE -ne 0) {
    throw "Spark paper source sync failed with exit code $LASTEXITCODE"
}
