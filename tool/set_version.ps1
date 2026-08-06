param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$')]
    [string]$VersionName,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2100000000)]
    [int]$BuildNumber
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$appVersionPath = Join-Path $projectRoot 'lib/src/core/config/app_version.dart'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$pubspecMatch = [regex]::Match(
    $pubspec,
    '(?m)^version:[ \t]*(?<name>[^+\s]+)\+(?<build>\d+)[ \t]*(?=\r?$)'
)
if (-not $pubspecMatch.Success) {
    throw 'pubspec.yaml 中没有找到合法的 version: <name>+<build>。'
}

$currentBuild = [int]$pubspecMatch.Groups['build'].Value
if ($BuildNumber -le $currentBuild) {
    throw "构建号必须递增。当前为 $currentBuild，请使用更大的值。"
}

$pubspec = [regex]::Replace(
    $pubspec,
    '(?m)^version:[ \t]*[^+\s]+\+\d+[ \t]*(?=\r?$)',
    "version: $VersionName+$BuildNumber",
    1
)

$appVersion = [System.IO.File]::ReadAllText($appVersionPath)
$appVersionPattern = "static const current = AppVersion\(name: '[^']+', buildNumber: \d+\);"
if (-not [regex]::IsMatch($appVersion, $appVersionPattern)) {
    throw 'app_version.dart 中没有找到 AppVersion.current。'
}
$appVersion = [regex]::Replace(
    $appVersion,
    $appVersionPattern,
    "static const current = AppVersion(name: '$VersionName', buildNumber: $BuildNumber);",
    1
)

[System.IO.File]::WriteAllText($pubspecPath, $pubspec, $utf8NoBom)
[System.IO.File]::WriteAllText($appVersionPath, $appVersion, $utf8NoBom)

Write-Output "Spark 版本已更新为 $VersionName+$BuildNumber。"
Write-Output "请同步更新 CHANGELOG.md，并运行 tool/verify_version.ps1。"
