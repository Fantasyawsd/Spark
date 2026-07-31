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

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --release
```

