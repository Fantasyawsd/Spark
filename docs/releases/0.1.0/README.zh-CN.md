# Spark 0.1.0 发布说明

> 状态：已发布（GitHub Release 里程碑）
> 发布日期：2026-08-10
> 版本：`0.1.0+2`

[English](README.md) | [简体中文](README.zh-CN.md)

## 概述

Spark 是面向个人研究者的 Flutter 论文发现、阅读和 AI 研究助手。0.1.0 是首个正式发布版本，基于公开仓库 `Fantasyawsd/Spark`，以 GitHub Release 里程碑形式发布（本版本未进入应用商店签名发布流程）。

## 功能清单

### 论文

- arXiv 远程论文流、分页、搜索和离线缓存。
- 推荐 / 关注 / 最新及 arXiv 主题频道，支持频道管理、频道级时间筛选、独立浏览位置和懒加载。
- 单页刷论文与双栏浏览选择。
- Markdown、LaTeX、英文 Abstract、中文摘要、内容关键词和六页论文阅读器（Abstract / 摘要 / 关键词 / 作者 / AI 解读 / 相关论文）。
- 点赞、评论、分享、已读、稍后阅读和收藏分组。
- 从搜索、收藏、历史和相关论文进入独立全屏阅读页。

### ChatPaper

- 置顶主聊天和按论文创建的聊天。
- DeepSeek 流式回答、深度思考、联网搜索、停止和重试。
- Markdown、公式、代码块和会话本地保存。
- 会话级系统提示词、回答风格和可组合 Skills；论文聊天可按需读取 PDF 全文并提供页码追溯引用。
- 左滑置顶或删除论文会话。

### 我的

- 默认收藏与自定义收藏分组。
- 收藏、稍后阅读和阅读历史可进入完整论文列表；支持主题设置、数据占用统计与分类清理。
- DeepSeek API Key 验证、保存、替换和删除。
- 应用版本、隐私说明和开源许可。

## 构建与渠道

- Android 三个 flavor：`development` / `staging` / `production`，应用 ID 与名称彼此隔离。
- 本版本为 GitHub Release 里程碑，未执行 production 签名构建、真机验收与商店门；相关门禁见 `docs/standards/release-management.md`「发布门」。

## 数据与迁移

- 本地数据使用版本化本地 JSON 存储（schemaId + schemaVersion + 逐版本 Migration）。
- 0.1.0 无破坏性数据迁移；阅读状态、互动、评论、搜索历史、中文摘要和聊天会话保存在当前设备。
- 论文目录使用 arXiv Atom API，失败时依次回退到设备缓存和内置种子论文。

## AI 与隐私

- DeepSeek BYOK：用户 Key 存入设备安全存储，公开构建不包含共享 Key。
- ChatPaper 和中文摘要请求会把必要的论文内容发送到 DeepSeek 官方接口。
- 正式应用商店发布前按商店要求提供隐私政策。

## 已知限制

- 社区、私信、通知、账号、云同步和内容发布不属于当前生产范围。
- 生产 arXiv 链路不产生引用数，展示入口保留。
- Windows 桌面为开发验证平台，第一验收平台为 Android 手机。

## 发布信息

- 仓库：https://github.com/Fantasyawsd/Spark
- Tag：`v0.1.0`（annotated）
- 发布基线：origin/main（归档 SHA 见提交记录）
- 回滚方案：本版本为里程碑标记，不涉及商店分发；如需回滚代码版本，使用新 patch 版本与递增构建号重新发布。
