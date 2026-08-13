# Spark

> Swipe papers, access research knowledge.

[English](README.md) | [简体中文](README.zh-CN.md)

Spark is a Flutter app for personal researchers to discover, read, and get AI assistance on academic papers. It aims to combine rapid paper discovery through an information feed, structured reading, Chinese-language understanding, and continuous conversation around papers into a single mobile app.

Current release: `0.1.0`. The primary acceptance platform is Android phones.

## Features

### Papers

- arXiv remote paper feed, pagination, search, and offline caching.
- Recommended / Following / Latest and arXiv topic channels, with channel management, per-channel time filtering, independent scroll positions, and lazy loading.
- Single-column swipe browsing and a two-column layout option.
- Markdown, LaTeX, English abstract, Chinese summary, content keywords, and a six-page paper reader (Abstract / Summary / Keywords / Authors / AI Insights / Related Papers).
- Like, comment, share, mark-as-read, read-later, and favorites groups.
- Dedicated fullscreen reading pages reachable from search, favorites, history, and related papers.

### ChatPaper

- A pinned main chat and per-paper chats.
- DeepSeek streaming responses, deep thinking, web search, stop, and retry.
- Markdown, math, code blocks, and local conversation persistence.
- Per-conversation system prompts, answer styles, and composable Skills; paper chats can read the full PDF on demand with page-referenced citations.
- Swipe left to pin or delete a paper conversation.

### Profile

- Default favorites and custom favorites groups.
- Favorites, read-later, and reading history open full paper lists; theme settings, storage usage statistics, and categorized cleanup.
- DeepSeek API key validation, save, replace, and delete.
- App version, privacy statement, and open-source licenses.

Community, direct messages, notifications, accounts, cloud sync, and content publishing are outside the current production scope. See the [development plan](docs/development.md) for upcoming paper discovery and reading improvements.

## Data & Privacy

- Paper catalogs use the arXiv Atom API; on failure it falls back to the on-device cache and then to built-in seed papers.
- Reading state, interactions, comments, search history, Chinese summaries, and chat sessions are stored on the device.
- AI is bring-your-own-key (BYOK); the user's key is stored in the device's secure storage. Release builds do not embed a shared key.
- ChatPaper and Chinese-summary requests send the necessary paper content to DeepSeek's official API.
- A privacy policy will be provided as required by app stores before a formal release.

## Project Structure

```text
|-- AGENTS.md                  Agent development, collaboration, and delivery guidelines
|-- CHANGELOG.md               User-visible version history
|-- README.md                  Project background, features, structure, and how to run
|-- .github/workflows/         Continuous integration for pull requests and main
|-- assets/                    Logo, launch images, and app static assets
|-- android/                   Android project, manifest, and signing config entry
|-- windows/                   Windows desktop host project
|-- docs/
|   |-- README.md              Development documentation index
|   |-- development.md         Development plan (product boundaries, priorities, domain directions)
|   |-- standards/             Architecture, collaboration, and version-management guidelines
|   |-- templates/             Workstream status and development report templates
|   |-- workstreams/           Status and reports for each development branch
|   `-- releases/<version>/    Release materials only
|-- lib/
|   |-- main.dart              App entrypoint and production dependency wiring
|   `-- src/
|       |-- app/               App shell, navigation, and composition root
|       |-- core/              Truly cross-cutting themes, animation, storage, and components
|       `-- features/
|           |-- papers/        Paper catalog, reading, interactions, and comments
|           |-- chat/          ChatPaper conversations and UI
|           |-- ai_settings/   DeepSeek credential configuration
|           |-- search/        Paper search and history
|           |-- profile/       Profile page and personal research data entry
|           |-- local_data/    Local data statistics and cleanup
|           |-- community/     Deferred module, not in production navigation
|-- test/                      Unit tests and widget tests
|-- tool/                      Development, build, and key-security helper scripts
|-- pubspec.yaml               Flutter package, assets, and version configuration
`-- analysis_options.yaml      Dart/Flutter static analysis rules
```

The codebase uses a feature-first layered architecture:

```text
presentation -> application -> domain <- data
```

See the [Code Structure Guidelines](docs/standards/code-structure.md) for full architecture constraints, and the [Release & Compatibility Guide](docs/standards/release-management.md) for release, environment, and compatibility rules.

## Development Docs

- [Documentation index](docs/README.md)
- [Development plan](docs/development.md)
- [Release & compatibility management](docs/standards/release-management.md)
- [AI agent collaboration guidelines](AGENTS.md)

## Development Environment

- Flutter 3.44.8 / Dart 3.12.2
- Android SDK: `D:\App\Android\Sdk`
- Windows builds require the Desktop C++ workload of Visual Studio Build Tools

```powershell
flutter pub get
flutter run -d windows --dart-define=SPARK_ENV=development
```

Both debug and release builds only read the key the user configures inside the app, stored in the device's secure storage; the API key is never compiled into the client via `dart-define`.

## Verification

```powershell
.\tool\verify_changed_dart_format.ps1
flutter analyze
flutter test
flutter build apk --release --flavor development --dart-define=SPARK_ENV=development
```

Android release builds require signing; until `android/key.properties` is configured, use `--profile` instead (AOT, performance equivalent to release, installable with the debug signature).

The project does not use Android emulators for routine acceptance. See the [Release & Compatibility Guide](docs/standards/release-management.md) for Android production signing, on-device acceptance, and release gates.
