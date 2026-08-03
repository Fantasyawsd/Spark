# 任务台账

## 基本信息

- 任务：论文频道基础（元数据语义修正 + 频道模型与目录 + 频道栏与频道管理页）
- 关联发布或里程碑：不关联发布（持续开发计划 `docs/development.md` §2.4 步骤 1–3）
- 分支：`qodercn/feature-paper-channels`
- Worktree：`../PaperFlow-worktrees/qodercn--feature-paper-channels`
- 基线提交：`b1a667b`（origin/main）
- 负责人：Fantasy（编排者）；执行：QoderCN Agent
- 状态：开发中
- 最近更新：2026-08-04 01:30

## 目标

让论文页具备结构化频道浏览能力：修正 `Paper` 元数据语义（source / venue / subject / publish time / affiliation），建立结构化频道模型、arXiv 分类目录与版本化频道偏好持久化，并重做顶部频道栏与「＋」频道管理页，使用户可以添加、删除、排序主题频道并按频道独立浏览。

## 非目标

- 不实现时间筛选入口改造（开发顺序步骤 4）。
- 不实现真实 arXiv 主题查询接入与缓存键 / 分页 / 位置恢复的完整验证（步骤 5）；本任务只建立频道状态容器与 UI，查询接入在后续任务验证。
- 不实现会议数据源端口与真实会议提供方（步骤 6）；会议频道不进入可添加状态。
- 不实现六页阅读结构、中文摘要缓存、PDF AI 解读、相关论文语义检索（步骤 7–10）。
- 不改动 community / messages 模块。

## 验收标准

- [ ] `Paper` 领域实体区分 `source`、`venue`、`journalReference`、`affiliation`；单位未知时为空，不以 `arXiv` 或其他占位值填充。
- [ ] 未知引用数不以 `0` 冒充真实数据（领域层改为可空未知语义）。
- [ ] arXiv 论文保存并展示 Primary Subject 与全部 Subjects；Subjects 只用于分类索引，不混入内容关键词。
- [ ] 频道栏为「文字 + 选中下划线」样式，横向滚动；推荐、关注、最新固定存在；「＋」固定在右侧始终可见。
- [ ] 「＋」打开频道管理页，含「按主题」分组、搜索与已添加状态；首批主题使用中文显示名并保留真实 arXiv 分类编号（cs.AI / cs.CL / cs.CV / cs.LG）。
- [ ] 用户频道支持添加、删除、排序，并持久化到版本化本地存储；添加或移除后频道栏与本地配置同步更新。
- [ ] 每个频道独立保存论文位置、加载状态和分页状态，互不污染。
- [ ] 频道与偏好的持久化结构带 schema 版本与 Migration；旧数据升级测试通过。
- [ ] 新增业务行为均有可独立运行的单元 / Widget 测试（频道领域模型、偏好迁移、频道栏与管理页关键流程）。
- [ ] `flutter analyze`、`flutter test`、定向格式检查通过。

## 写入范围

### 独占路径

- `lib/src/features/papers/`
- `test/features/papers/`（及论文相关既有测试文件的适配修改）
- `docs/workstreams/qodercn--feature-paper-channels/`

### 共享路径

- `lib/src/app/`：组合根装配新频道仓储 / 目录源时可能小幅修改；修改前确认无并行任务写入（当前并行 worktree 为 research-chat-experience 与 rikkahub-design，均不涉及论文频道装配）。

## 依赖关系

- 上游任务：无（基线 b1a667b）。
- 外部接口或数据源：arXiv Atom API（既有适配器）；首批主题目录为内置结构化目录，不新增远程依赖。

## 实施计划

1. 步骤 1（元数据语义）：修正 `Paper` 领域实体——拆分 `source` / `venue` / `journalReference` / `affiliation`，Subjects 结构化（primary + 全部），publish / update time 语义，引用数改为未知语义；同步修改 arXiv DTO、缓存 Record、Mapper、种子数据与本地缓存 schema Migration；补充单元测试。
2. 步骤 2（频道模型与目录）：领域层建立频道模型（固定：推荐 / 关注 / 最新；用户：主题 / 会议频道）、arXiv 分类目录（首批 4 个主题，显示名 + 分类编号）与频道偏好实体；数据层实现版本化频道偏好仓储（含 Migration 与内存测试实现）。
3. 步骤 3（频道栏 UI）：重做顶部频道栏（文字 + 选中下划线、横向滚动、「＋」固定右侧）与「＋」频道管理页（按主题、搜索、已添加状态、添加 / 删除 / 排序）；每频道独立位置、加载与分页状态；Widget 测试覆盖关键流程。
4. 每个检查点（领域契约变更前后、UI 方案确认后、合并前）原子提交并更新台账。

## 当前进度

- 已完成：必读文档读取、基线确认、分支与 worktree 创建、台账初始化；步骤 1（`Paper` 元数据语义修正，提交 1b3f8bb）；步骤 2（频道模型、arXiv 主题目录与版本化频道偏好仓储，提交 f2cf901）。
- 正在进行：无。
- 下一步：步骤 3（频道栏 UI 与「＋」频道管理页）。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-03 | 任务范围取开发顺序步骤 1–3，编排者确认 | 步骤 1–3 构成频道能力的最小纵向闭环 | 时间筛选、arXiv 主题查询验证、会议数据源留给后续任务 |
| 2026-08-03 | 分支命名 `qodercn/feature-paper-channels`，遵循 release-management.md §2 Agent 分支格式，编排者确认 | Agent 分支与人类分支区分 | worktree slug 为 `qodercn--feature-paper-channels` |
| 2026-08-03 | 会议频道不进入可添加状态 | 会议频道需真实 `VenueCatalogSource`（步骤 6），无真实数据源不得进入生产入口 | 频道管理页会议部分暂不开放添加，具体形态在 /develop 阶段与编排者确认 |
| 2026-08-04 | `Paper.topics` 拆为 `subjects`（arXiv 分类）与 `contentKeywords`（内容关键词），`venue`/`journalReference`/`comment` 分离，`firstAffiliation` 改为 `affiliations` 列表，引用数改可空 | 落实开发计划「数据语义」要求，未知数据保持未知 | 全量映射、缓存、展示与测试同步改造 |
| 2026-08-04 | `RelatedPaper.venue` 一并改为可空 | 相关论文同样不能用 `arXiv` 冒充 venue | 缓存 schema v2 迁移同时还原相关论文占位 venue |
| 2026-08-04 | 论文缓存 `papers.catalog-cache` schema 升到 v2，提供单步 1→2 迁移 | 持久化结构变化必须版本化迁移 | 旧缓存可读且还原未知语义；迁移测试覆盖 |
| 2026-08-04 | 频道偏好新建独立 schema `papers.channel-preferences`（v1），不迁移旧 `extraTopics` 自由文本 | 旧自定义主题为非结构化字符串，不符合「主题必须来自结构化 arXiv 分类目录」要求 | 旧自由文本主题不保留；旧偏好字段留待清理任务处理 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter analyze` | 通过（No issues found） | 2026-08-04 |
| `flutter test` | 通过（204/204，步骤 1）；通过（215/215，步骤 2） | 2026-08-04 |
| `tool/verify_changed_dart_format.ps1` | 通过（步骤 1：26 个文件；步骤 2：35 个文件） | 2026-08-04 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：可合并 / 需修复 / 需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 6e5f87a | docs: add paper-channels workstream ledger | /start 台账初始化 | 仅文档 |
| 1b3f8bb | feat(papers): split paper metadata semantics and keep unknown data unknown | 步骤 1：元数据语义修正 | analyze 通过；204 测试通过；格式门禁通过 |
| f2cf901 | feat(papers): add channel model, arXiv subject catalog and channel preferences | 步骤 2：频道模型与偏好持久化 | analyze 通过；215 测试通过；格式门禁通过 |

## 交付记录（合并前补齐）

### 交付摘要

（合并前补齐）

### 实际变更

- 领域与业务逻辑：
- 数据与基础设施：
- 界面与交互：
- 测试与工具：
- 文档：

### 兼容性与迁移

- 本地数据迁移：（合并前补齐）
- API 或领域契约变化：（合并前补齐）
- 旧版本兼容性：（合并前补齐）

### 已知风险与回滚

- 已知风险：
- 回滚方式：

### 文档更新建议

- （合并前补齐：`docs/development.md` 论文领域状态更新建议）

### 未完成与后续工作

- 时间筛选入口改造（开发顺序步骤 4）。
- 真实 arXiv 主题查询接入与缓存键 / 分页 / 位置恢复验证（步骤 5）。
- 会议数据源端口与首个真实会议提供方纵向闭环（步骤 6）。
