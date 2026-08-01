param(
    [switch]$RequireReleaseTag,
    [string]$BaseRevision = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$appVersionPath = Join-Path $projectRoot 'lib/src/core/config/app_version.dart'
$changelogPath = Join-Path $projectRoot 'CHANGELOG.md'
$versionPattern = '(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'

function Get-VersionMetadata {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $match = [regex]::Match(
        $Content,
        "(?m)^version:[ \t]*(?<name>$versionPattern)\+(?<build>[1-9]\d*)[ \t]*(?=\r?`$)"
    )
    if (-not $match.Success) {
        throw "$Source 版本必须使用 <major>.<minor>.<patch>[-prerelease]+<build>。"
    }

    return [pscustomobject]@{
        Name = $match.Groups['name'].Value
        BuildNumber = [int]$match.Groups['build'].Value
    }
}

function Compare-NumericIdentifier {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )

    $normalizedLeft = $Left.TrimStart('0')
    $normalizedRight = $Right.TrimStart('0')
    if ($normalizedLeft.Length -eq 0) { $normalizedLeft = '0' }
    if ($normalizedRight.Length -eq 0) { $normalizedRight = '0' }

    if ($normalizedLeft.Length -ne $normalizedRight.Length) {
        return [Math]::Sign($normalizedLeft.Length - $normalizedRight.Length)
    }
    return [Math]::Sign([string]::CompareOrdinal($normalizedLeft, $normalizedRight))
}

function Compare-SemVer {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )

    $semVerPattern = '^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<pre>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'
    $leftMatch = [regex]::Match($Left, $semVerPattern)
    $rightMatch = [regex]::Match($Right, $semVerPattern)
    if (-not $leftMatch.Success -or -not $rightMatch.Success) {
        throw '无法比较非法的语义化版本。'
    }

    foreach ($part in @('major', 'minor', 'patch')) {
        $comparison = Compare-NumericIdentifier `
            -Left $leftMatch.Groups[$part].Value `
            -Right $rightMatch.Groups[$part].Value
        if ($comparison -ne 0) { return $comparison }
    }

    $leftPre = $leftMatch.Groups['pre'].Value
    $rightPre = $rightMatch.Groups['pre'].Value
    if ([string]::IsNullOrEmpty($leftPre) -and [string]::IsNullOrEmpty($rightPre)) {
        return 0
    }
    if ([string]::IsNullOrEmpty($leftPre)) { return 1 }
    if ([string]::IsNullOrEmpty($rightPre)) { return -1 }

    $leftParts = @($leftPre -split '\.')
    $rightParts = @($rightPre -split '\.')
    $count = [Math]::Min($leftParts.Count, $rightParts.Count)
    for ($index = 0; $index -lt $count; $index++) {
        $leftPart = $leftParts[$index]
        $rightPart = $rightParts[$index]
        $leftNumeric = $leftPart -match '^\d+$'
        $rightNumeric = $rightPart -match '^\d+$'

        if ($leftNumeric -and $rightNumeric) {
            $comparison = Compare-NumericIdentifier -Left $leftPart -Right $rightPart
        } elseif ($leftNumeric) {
            $comparison = -1
        } elseif ($rightNumeric) {
            $comparison = 1
        } else {
            $comparison = [Math]::Sign([string]::CompareOrdinal($leftPart, $rightPart))
        }
        if ($comparison -ne 0) { return $comparison }
    }

    return [Math]::Sign($leftParts.Count - $rightParts.Count)
}

$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$current = Get-VersionMetadata -Content $pubspec -Source 'pubspec.yaml'
$versionName = $current.Name
$buildNumber = $current.BuildNumber

$appVersion = [System.IO.File]::ReadAllText($appVersionPath)
$appVersionMatch = [regex]::Match(
    $appVersion,
    "static const current = AppVersion\(name: '(?<name>[^']+)', buildNumber: (?<build>\d+)\);"
)
if (-not $appVersionMatch.Success) {
    throw 'app_version.dart 中没有找到 AppVersion.current。'
}
if ($appVersionMatch.Groups['name'].Value -ne $versionName -or
    [int]$appVersionMatch.Groups['build'].Value -ne $buildNumber) {
    throw 'pubspec.yaml 与 AppVersion.current 不一致，请使用 tool/set_version.ps1 更新。'
}

if (-not [string]::IsNullOrWhiteSpace($BaseRevision)) {
    if ($BaseRevision -match '^0+$') {
        $BaseRevision = @(git -C $projectRoot rev-list --max-parents=0 HEAD) |
            Select-Object -First 1
    }

    & git -C $projectRoot rev-parse --verify --quiet "$BaseRevision^{commit}" *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "无法解析版本检查基线提交：$BaseRevision"
    }

    $basePubspec = @(git -C $projectRoot show "${BaseRevision}:pubspec.yaml") -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "无法从基线 $BaseRevision 读取 pubspec.yaml。"
    }
    $base = Get-VersionMetadata -Content $basePubspec -Source "基线 $BaseRevision 的 pubspec.yaml"

    if ((Compare-SemVer -Left $versionName -Right $base.Name) -lt 0) {
        throw "版本号不能从 $($base.Name) 降级为 $versionName。"
    }

    $metadataChanged = $versionName -ne $base.Name -or $buildNumber -ne $base.BuildNumber
    if ($metadataChanged -and $buildNumber -le $base.BuildNumber) {
        throw "版本元数据发生变化时构建号必须递增。基线为 $($base.BuildNumber)，当前为 $buildNumber。"
    }
}

$changelog = [System.IO.File]::ReadAllText($changelogPath)
$escapedVersion = [regex]::Escape($versionName)
if (-not [regex]::IsMatch($changelog, "(?m)^## \[$escapedVersion\](?:\s|$)")) {
    throw "CHANGELOG.md 缺少 [$versionName] 版本条目。"
}

if ($RequireReleaseTag) {
    $expectedTag = "v$versionName"
    $headTags = @(git -C $projectRoot tag --points-at HEAD)
    if ($LASTEXITCODE -ne 0 -or $headTags -notcontains $expectedTag) {
        throw "当前提交缺少发布 Tag $expectedTag。"
    }

    $tagType = @(git -C $projectRoot cat-file -t "refs/tags/$expectedTag") |
        Select-Object -First 1
    if ($LASTEXITCODE -ne 0 -or $tagType -ne 'tag') {
        throw "发布 Tag $expectedTag 必须是 annotated Tag。"
    }

    if (-not [regex]::IsMatch(
        $changelog,
        "(?m)^## \[$escapedVersion\] - \d{4}-\d{2}-\d{2}[ \t]*(?=\r?`$)"
    )) {
        throw "正式发布前必须把 CHANGELOG.md 的 [$versionName] 标题更新为发布日期。"
    }
    if (-not [regex]::IsMatch(
        $changelog,
        "(?m)^\[$escapedVersion\]:[ \t]*\S+/releases/tag/v$escapedVersion[ \t]*(?=\r?`$)"
    )) {
        throw "CHANGELOG.md 缺少 [$versionName] 的发布链接。"
    }
    if (-not [regex]::IsMatch(
        $changelog,
        "(?m)^\[Unreleased\]:[ \t]*\S+/compare/v$escapedVersion\.\.\.HEAD[ \t]*(?=\r?`$)"
    )) {
        throw 'CHANGELOG.md 的 [Unreleased] 链接必须从当前发布 Tag 开始比较。'
    }
}

Write-Output "版本检查通过：$versionName+$buildNumber。"
