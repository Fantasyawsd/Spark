param(
    [switch]$RequireReleaseTag
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$appVersionPath = Join-Path $projectRoot 'lib/src/core/config/app_version.dart'
$changelogPath = Join-Path $projectRoot 'CHANGELOG.md'

$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$pubspecMatch = [regex]::Match(
    $pubspec,
    '(?m)^version:[ \t]*(?<name>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)\+(?<build>[1-9]\d*)[ \t]*(?=\r?$)'
)
if (-not $pubspecMatch.Success) {
    throw 'pubspec.yaml 版本必须使用 <major>.<minor>.<patch>[-prerelease]+<build>。'
}

$versionName = $pubspecMatch.Groups['name'].Value
$buildNumber = [int]$pubspecMatch.Groups['build'].Value
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
}

Write-Output "版本检查通过：$versionName+$buildNumber。"
