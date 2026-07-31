param(
    [Parameter(Position = 0)]
    [string]$FlutterCommand = "run",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = "Stop"

function Get-DeepSeekSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$DefaultValue = ""
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, "User")
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = $DefaultValue
    }
    return $value
}

$apiKey = Get-DeepSeekSetting -Name "DEEPSEEK_API_KEY"
$baseUrl = Get-DeepSeekSetting -Name "DEEPSEEK_BASE_URL" -DefaultValue "https://api.deepseek.com"
$model = Get-DeepSeekSetting -Name "DEEPSEEK_MODEL" -DefaultValue "deepseek-v4-flash"
$reasoningEffort = Get-DeepSeekSetting -Name "DEEPSEEK_REASONING_EFFORT" -DefaultValue "medium"

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "缺少用户环境变量 DEEPSEEK_API_KEY。"
}
if ($baseUrl -notmatch "^https://api\.deepseek\.com/?$") {
    throw "DEEPSEEK_BASE_URL 必须指向 DeepSeek 官方接口：https://api.deepseek.com"
}

$flutter = "D:\app\flutter\bin\flutter.bat"
if (-not (Test-Path $flutter)) {
    throw "未找到 Flutter SDK：$flutter"
}

Write-Host "使用独立 DeepSeek 配置（密钥已隐藏）"
Write-Host "协议：Anthropic Messages"
Write-Host "接口：$baseUrl"
Write-Host "模型：$model"
Write-Host "思考强度：$reasoningEffort"

& $flutter $FlutterCommand @FlutterArguments `
    "--dart-define=DEEPSEEK_API_KEY=$apiKey" `
    "--dart-define=DEEPSEEK_BASE_URL=$baseUrl" `
    "--dart-define=DEEPSEEK_MODEL=$model" `
    "--dart-define=DEEPSEEK_REASONING_EFFORT=$reasoningEffort"

exit $LASTEXITCODE
