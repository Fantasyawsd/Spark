# Changelog

Spark 的用户可见变更记录在此文件中。格式遵循 Keep a Changelog，发布版本遵循语义化版本。

## [Unreleased]

## [0.1.0] - 2026-08-10

### Added

- Android development、staging、production 构建渠道。
- 版本一致性、变更文件格式检查、版本更新工具和 GitHub Actions CI。
- 生产默认关闭的实验功能开关基础层。

### Changed

- Android 渠道只通过包名和应用名称区分，版本名称统一来自 `pubspec.yaml`。
- 发布门拒绝环境错配、版本倒退、未签名 release、轻量 Tag 和未填写发布日期的正式 Tag。

## [0.0.1]

### Added

- arXiv 论文信息流、搜索、分页、缓存和离线回退。
- 论文 Abstract、中文解读、相关论文和本地互动。
- ChatPaper 主聊天与论文聊天、DeepSeek 流式回答、深度思考和联网搜索。
- 收藏分组、阅读历史、稍后阅读、主题、凭据和本地数据管理。

### Security

- DeepSeek API Key 使用设备安全存储，公开构建不包含共享 Key。
- Android release 缺少正式签名配置时拒绝构建。

[Unreleased]: https://github.com/Fantasyawsd/Spark/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Fantasyawsd/Spark/releases/tag/v0.1.0
