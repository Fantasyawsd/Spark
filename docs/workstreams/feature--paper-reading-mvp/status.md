# 任务台账

> 单文件任务台账。任务已合入 `main`，本页已补录最终合并归档，后续仅补充勘误。

## 基本信息

- 任务：论文阅读 MVP（时间筛选、六页阅读、纯化摘要文案、内容关键词）
- 关联发布或里程碑：不绑定发布版本；P1 论文发现与结构化阅读
- 分支：`feature/paper-reading-mvp`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\feature--paper-reading-mvp`
- 基线提交：`e2ac254`
- 负责人：Fantasy
- 状态：已合并
- 最近更新：`2026-08-07 00:10`

## 目标

交付一个可验证的论文阅读 MVP：每个频道可使用六种发布时间范围筛选；论文内容按 Abstract、摘要、AI 解读、相关论文、关键词、作者与单位六页浏览；中文摘要使用纯内容状态文案；用户可按需生成并独立缓存 5–12 个内容关键词。

## 非目标

- 不下载或解析 PDF，不实现 PDF 分块与六问 AI 解读。
- 不把 Abstract 生成结果冒充 PDF 全文解读。
- 不把六问结果注入 ChatPaper；该能力等待后端 PDF 解析链路。
- 不实现相关论文语义检索、embedding、全文向量索引或引用图谱。
- 不改变社区、私信、账号、同步与发布版本。

## 验收标准

- [x] 当前频道支持不限时间、最新发布日、最近 7 天、最近 30 天、选择日期、自定义时间范围。
- [x] 时间范围影响真实远程查询及离线缓存结果，不同频道/范围的分页和位置不串联。
- [x] 每篇论文默认进入 Abstract，六个内容标签可横向滚动并与左右滑动同步；作者页仅展示可靠作者数据。
- [x] 中文摘要只显示内容状态，不暴露 DeepSeek、模型、流式或思考开关。
- [x] 关键词仅在用户触发后生成，得到 5–12 个去重语义关键词，与 arXiv Subjects 分开。
- [x] 关键词使用独立版本化缓存，目录刷新不会覆盖；输入或 prompt 版本变化时旧缓存不再使用。
- [x] AI 解读与相关论文页面不声称尚未实现的 PDF 六问或语义检索能力。
- [x] 新增业务行为具有独立单元或 Widget 测试，并通过任务要求的验证门禁。

## 写入范围

### 独占路径

- `lib/src/features/papers/`
- `test/` 中本任务新增及论文阅读、时间筛选、摘要、关键词相关测试
- `docs/workstreams/feature--paper-reading-mvp/status.md`

### 共享路径

- `lib/src/app/paperflow_dependencies.dart`：仅做本任务依赖装配。
- `lib/src/app/paperflow_app.dart`：仅在关键词/上下文依赖传递需要时修改。
- `lib/paperflow.dart`：仅增加本任务公开导出。
- `docs/development.md`：当前主工作树已有未提交改动，本任务开发阶段不修改；只在 `/finish` 时由编排者协调同步。

## 依赖关系

- 上游任务：论文频道目录与结构化元数据（基线已包含）。
- 外部接口或数据源：arXiv Atom API；DeepSeek BYOK 兼容 Messages API。
- 后续依赖：PDF 六问需要自有后端；相关语义检索需要明确 embedding、索引和引用数据契约。

## 实施计划

1. 实现时间范围领域模型、远程/离线查询、每频道状态、偏好迁移与筛选 UI。
2. 将三页阅读器改为六页横向结构，纯化摘要文案并准确表达未实现能力。
3. 实现内容关键词服务、独立缓存、controller、按需生成 UI 与依赖装配。
4. 仅让真实可用的缓存关键词进入论文聊天上下文；不注入空六问占位。
5. 执行定向和完整验证，更新台账并等待用户确认后再启动 Windows 应用。

## 当前进度

- 已完成：频道时间筛选、六页阅读器、摘要文案纯化、关键词生成与独立缓存、有效关键词 ChatPaper 上下文接入、定向与完整自动验证、Windows 人工验收。
- 正在进行：无
- 下一步：无；PDF 全文与六问解读由 ChatPaper 后续任务承接
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-05 | 本轮采用分阶段 MVP | 当前客户端没有 PDF parser、embedding、向量库或引用图谱基础 | 本轮只交付时间筛选、六页、摘要文案和关键词 |
| 2026-08-05 | PDF 六问等待后端 | 用户选择后端边界，避免 Abstract 冒充全文 | AI 解读页只呈现真实能力状态 |
| 2026-08-05 | 相关论文检索暂不实施 | 用户明确后续再做语义检索 | 保留已有结构化关系与空状态 |
| 2026-08-05 | 关键词使用独立缓存 | AI 派生数据不应被目录刷新覆盖 | 新建独立 schema 和本地数据清理入口 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `git branch --show-current` / `git status --short` / `git log -1 --oneline` | `feature/paper-reading-mvp`，工作区创建时干净，基线 `e2ac254` | 2026-08-05 |
| `flutter test test/paper_keyword_test.dart test/paper_chat_context_test.dart test/ui_preview_test.dart` | 32 项定向测试通过 | 2026-08-06 |
| `.\\tool\\verify_changed_dart_format.ps1` | 37 个变更 Dart 文件格式检查通过 | 2026-08-06 |
| `flutter analyze` | 通过，No issues found | 2026-08-06 |
| `flutter test` | 258 项完整测试通过 | 2026-08-06 |
| `flutter build apk --debug --flavor development --dart-define=PAPERFLOW_ENV=development` | 通过，生成 `app-development-debug.apk` | 2026-08-06 |
| `git diff --check` | 通过；仅生成的 Windows plugin 文件提示 LF/CRLF 转换 | 2026-08-06 |
| `flutter run -d windows --dart-define=PAPERFLOW_ENV=development` | Windows 应用启动成功；编排者人工验收通过，并确认作者页与相关论文占位调整 | 2026-08-06 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付记录（合并前补齐）

### 交付摘要

完成论文阅读 MVP：频道级发布时间筛选、六页阅读信息架构、纯内容中文摘要状态、按需关键词生成与独立缓存，以及有效关键词 ChatPaper 上下文。

### 实际变更

- 领域与业务逻辑：新增发布时间范围、查询边界、关键词记录、生成解析、freshness 校验与 controller。
- 数据与基础设施：arXiv 查询支持 submittedDate；偏好 schema 升级至 v2；新增 `papers.keywords` 独立版本化缓存并纳入论文缓存清理。
- 界面与交互：六页阅读器、横向滚动标签、仅作者列表、相关论文占位入口、时间选择器、按需关键词生成状态和能力边界文案。
- 测试与工具：增加时间查询、频道持久化、关键词解析/缓存/上下文及六页 Widget 覆盖；完整门禁通过。
- 文档：更新本任务台账与验证证据。

### 兼容性与迁移

- 本地数据迁移：`papers.preferences` 从 schema v1 迁移至 v2，新增空 `timeRanges`；关键词使用全新 `papers.keywords` schema v1。
- API 或领域契约变化：`PaperFeedQuery` 与 arXiv catalog source 增加发布时间边界；阅读器和组合根增加关键词服务与仓库依赖。
- 旧版本兼容性：旧偏好默认迁移为不限时间；关键词缓存为新增文件，不影响目录和摘要缓存。

### 已知风险与回滚

- 已知风险：时间边界与 arXiv 查询语义、关键词生成结果约束、六页在小屏上的标签滚动。
- 回滚方式：按原子提交 `git revert`；独立关键词缓存可清理，旧目录与摘要缓存不受影响。

### 文档更新建议

- `/finish` 时协调主工作树中的 `docs/development.md`，仅更新真实完成项。

### 未完成与后续工作

- 后端 PDF 下载、提取、分块和六问解读。
- 六问结果作为 ChatPaper 默认上下文。
- 相关论文语义检索、全文向量与引用图谱。

## 合并归档

- 最终状态：已合并
- 合入分支：`main`
- 最终集成提交：`42eb4d1`（`merge: complete paper reading MVP`）
- Pull Request：无
- 合并时间：2026-08-06 02:37（+08:00）
- main 集成验证：`git merge-base --is-ancestor 8ec9fde main` 通过；原台账记录完整格式、analyze、测试和 development APK 门禁通过
- 开发计划更新：已核对 `docs/development.md` §3.1 第 3–8 项，均已标记为已完成；第 9 项 PDF/六问已拆分为部分完成
- 最终后续项：后端 PDF 六问解读、相关论文语义检索、全文向量与引用图谱
