# Changelog

PaperFlow 的用户可见变更记录在此文件中。格式遵循 Keep a Changelog，发布版本遵循语义化版本。

## [Unreleased]

### Added

- Android development、staging、production 构建渠道。
- 版本一致性、变更文件格式检查、版本更新工具和 GitHub Actions CI。
- 生产默认关闭的实验功能开关基础层。

## [0.1.0] - Release candidate

### Added

- arXiv 论文信息流、搜索、分页、缓存和离线回退。
- 论文 Abstract、中文解读、相关论文和本地互动。
- ChatPaper 主聊天与论文聊天、DeepSeek 流式回答、深度思考和联网搜索。
- 收藏分组、阅读历史、稍后阅读、主题、凭据和本地数据管理。

### Security

- DeepSeek API Key 使用设备安全存储，公开构建不包含共享 Key。
- Android release 缺少正式签名配置时拒绝构建。

[Unreleased]: https://github.com/Fantasyawsd/PaperFlowDev/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Fantasyawsd/PaperFlowDev/releases/tag/v0.1.0
