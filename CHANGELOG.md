# Changelog

Spark 的用户可见变更记录在此文件中。格式遵循 Keep a Changelog，发布版本遵循语义化版本。

## [Unreleased]

### Added

- 推荐频道支持近期热点信号：GitHub star 增速、短期引用增速、Web 热度（LLM Trend Scout 身份核验）与 24–72 小时 Trend Boost 增益。
- 信息流卡片展示「Trending · 原因」热点徽标。
- 个性化推荐：设备本地行为日志（可关闭、可清除、90 天保留期）聚合为匿名偏好画像，随推荐请求上送；服务端按画像召回 Personalized Pool 并按偏好加权混排。
- 信息流卡片展示「为你推荐」徽标（personalized 池条目）。
- 「我的」页新增个性化推荐开关与「清除行为数据」入口；行为数据纳入本地数据占用统计与清理。

### Changed

- 推荐分数口径升级至 score.v4（纳入个性化偏好分量），批次按分数版本追溯。

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
