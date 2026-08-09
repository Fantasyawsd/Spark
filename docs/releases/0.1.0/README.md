# Spark 0.1.0 Release Notes

> Status: Released (GitHub Release milestone)
> Release date: 2026-08-10
> Version: `0.1.0+2`

[English](README.md) | [简体中文](README.zh-CN.md)

## Overview

Spark is a Flutter app for personal researchers to discover, read, and get AI assistance on academic papers. 0.1.0 is the first formal release, published from the public repository `Fantasyawsd/PaperFlowDev` as a GitHub Release milestone (this version does not go through the app-store signed release process).

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

## Builds & Channels

- Android flavors: `development` / `staging` / `production`, with isolated app IDs and names.
- This release is a GitHub Release milestone; production signed builds, on-device acceptance, and store gates were not performed. See "Release gates" in `docs/standards/release-management.md`.

## Data & Migration

- Local data uses versioned local JSON storage (schemaId + schemaVersion + per-version migrations).
- 0.1.0 has no breaking data migrations; reading state, interactions, comments, search history, Chinese summaries, and chat sessions are stored on the device.
- Paper catalogs use the arXiv Atom API, falling back to the on-device cache and then built-in seed papers on failure.

## AI & Privacy

- DeepSeek BYOK: the user's key is stored in the device's secure storage; public builds do not embed a shared key.
- ChatPaper and Chinese-summary requests send the necessary paper content to DeepSeek's official API.
- A privacy policy will be provided as required by app stores before a store release.

## Known Limitations

- Community, direct messages, notifications, accounts, cloud sync, and content publishing are outside the current production scope.
- The production arXiv pipeline does not produce citation counts; the UI entry remains.
- Windows desktop is the development verification platform; the primary acceptance platform is Android phones.

## Release Information

- Repository: https://github.com/Fantasyawsd/PaperFlowDev
- Tag: `v0.1.0` (annotated)
- Release baseline: origin/main (the archived SHA is in the commit history)
- Rollback: this release is a milestone marker and involves no store distribution; to roll back the code version, release a new patch version with an incremented build number.
