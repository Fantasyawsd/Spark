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

AI paper conversations use DeepSeek's OpenAI-compatible chat completions API.
Provide the key at build or run time instead of committing it to the repository:

```powershell
flutter run -d windows --dart-define=DEEPSEEK_API_KEY=your_key
flutter build apk --release --dart-define=DEEPSEEK_API_KEY=your_key
```

Optional configuration:

```text
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-chat
```

`dart-define` prevents accidental source-control exposure, but a key embedded in
a client application can still be extracted. Production releases should call a
server-side PaperFlow endpoint that stores the DeepSeek key securely.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --release
```
