# PaperFlow

PaperFlow is a Flutter prototype for discovering, reading, saving, and
discussing academic papers in a vertical information feed.

## Features

- Full-screen vertical paper feed
- Two-column paper browser with selection back to the reader
- Abstract, Chinese abstract, and related-paper tabs
- Shared like and save state across feed and grid views
- Comments and AI analysis bottom sheet
- Community, messages, and profile pages
- Runtime theme color selection
- Windows and Android platform projects

## Architecture

```text
lib/src/
|-- app/                         Application shell and navigation
|-- core/                        Theme and shared widgets
`-- features/
    |-- papers/
    |   |-- application/         Paper interaction state
    |   |-- data/                Demo repository
    |   |-- domain/              Entity and repository contract
    |   `-- presentation/        Feed, grid, comments, and AI UI
    |-- community/
    |-- messages/
    `-- profile/
```

`PaperController` is the single source of truth for the selected paper, layout
mode, topics, likes, and saves. `PaperRepository` isolates the UI from the data
source so the demo repository can later be replaced by an API-backed one.

## Paper data sources

The paper data layer now includes adapters for the recommended ingestion path:

- `ArxivJsonlImporter` streams the official Kaggle snapshot and filters target categories.
- `ArxivOaiClient` reads arXiv OAI-PMH pages and persists `resumptionToken` through `ArxivPaperSyncService`.
- `OpenAlexClient` enriches an arXiv record with citations, institutions, concepts, and related works.

These adapters are intentionally not called from the app startup path. A backend
or an import worker should use them to upsert records into its database, then
expose the existing `PaperRepository` contract to Flutter. No Kaggle credential,
database credential, or third-party API key belongs in the mobile client.

## Requirements

- Flutter SDK 3.44 or newer
- Dart SDK 3.12 or newer
- Android SDK for APK builds
- Visual Studio Build Tools with Desktop C++ support for Windows builds

The local development setup used for this project is:

```text
Flutter: D:\app\flutter
Android SDK: D:\app\Android\Sdk
```

## Run

```powershell
flutter pub get
flutter run -d windows
```

## DeepSeek AI

PaperFlow uses DeepSeek as its only model provider. Both normal chat and
web-search chat use DeepSeek's remote Anthropic-compatible Messages endpoint.
Claude, Codex, and localhost proxy settings are not read by the application.

Configure independent user environment variables:

```powershell
[Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', 'your_key', 'User')
[Environment]::SetEnvironmentVariable('DEEPSEEK_BASE_URL', 'https://api.deepseek.com', 'User')
[Environment]::SetEnvironmentVariable('DEEPSEEK_MODEL', 'deepseek-v4-flash', 'User')
```

Run or build with the repository helper:

```powershell
.\tool\flutter_with_deepseek.ps1 -FlutterCommand run -FlutterArguments @('-d', 'windows')
.\tool\flutter_with_deepseek.ps1 -FlutterCommand build -FlutterArguments @('apk', '--release')
```

Normal chat sends an Anthropic Messages request without tools. Web search uses
the same endpoint with DeepSeek's remote `web_search_20250305` tool. The helper
passes settings through `dart-define` without printing the key. A key embedded
in a client can still be extracted, so production should use a PaperFlow server
that stores the DeepSeek key securely.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --release
```
