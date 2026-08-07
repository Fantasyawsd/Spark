param(
    [string]$BaseRevision = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-GitLines {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = @(& git -C $projectRoot @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
    return $output
}

if ([string]::IsNullOrWhiteSpace($BaseRevision)) {
    $mainRevision = 'main'
    & git -C $projectRoot rev-parse --verify --quiet 'main^{commit}' *> $null
    if ($LASTEXITCODE -ne 0) {
        $mainRevision = 'origin/main'
        & git -C $projectRoot rev-parse --verify --quiet 'origin/main^{commit}' *> $null
    }
    if ($LASTEXITCODE -eq 0) {
        $BaseRevision = (Invoke-GitLines -Arguments @(
            'merge-base', $mainRevision, 'HEAD'
        ) | Select-Object -First 1)
    }
}

$committedDartFiles = @()
if (-not [string]::IsNullOrWhiteSpace($BaseRevision)) {
    if ($BaseRevision -match '^0+$') {
        $committedDartFiles = @(Invoke-GitLines -Arguments @(
            'ls-files', '--', '*.dart'
        ))
    } else {
        & git -C $projectRoot rev-parse --verify --quiet "$BaseRevision^{commit}" *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "无法解析格式检查基线提交：$BaseRevision"
        }

        $committedDartFiles = @(Invoke-GitLines -Arguments @(
            'diff', '--name-only', '--diff-filter=ACMR', "$BaseRevision...HEAD", '--', '*.dart'
        ))
    }
}

$dartFiles = @(
    $committedDartFiles
    Invoke-GitLines -Arguments @(
        'diff', '--name-only', '--diff-filter=ACMR', 'HEAD', '--', '*.dart'
    )
    Invoke-GitLines -Arguments @(
        'ls-files', '--others', '--exclude-standard', '--', '*.dart'
    )
) | Where-Object {
    $_ -and (Test-Path -LiteralPath (Join-Path $projectRoot $_) -PathType Leaf)
} | Sort-Object -Unique
if ($dartFiles.Count -eq 0) {
    Write-Output '没有需要检查的 Dart 文件。'
    exit 0
}

$batchSize = 40
Push-Location $projectRoot
try {
    for ($index = 0; $index -lt $dartFiles.Count; $index += $batchSize) {
        $lastIndex = [Math]::Min($index + $batchSize - 1, $dartFiles.Count - 1)
        $batch = @($dartFiles[$index..$lastIndex])
        & dart format --output=none --set-exit-if-changed @batch
        if ($LASTEXITCODE -ne 0) {
            throw 'Dart 格式检查失败。请对输出中的文件运行 dart format。'
        }
    }
} finally {
    Pop-Location
}

Write-Output "Dart 格式检查通过：$($dartFiles.Count) 个文件。"
