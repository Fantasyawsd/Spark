# 任务台账

## 基本信息

- 任务：论文频道基础（元数据语义修正 + 频道模型与目录 + 频道栏与频道管理页）
- 关联发布或里程碑：不关联发布（持续开发计划 `docs/development.md` §2.4 步骤 1–3）
- 分支：`qodercn/feature-paper-channels`
- Worktree：`../PaperFlow-worktrees/qodercn--feature-paper-channels`
- 基线提交：`b1a667b`（origin/main）
- 负责人：Fantasy（编排者）；执行：QoderCN Agent
- 状态：开发中
- 最近更新：2026-08-04 05:00

## 目标

让论文页具备结构化频道浏览能力：修正 `Paper` 元数据语义（source / venue / subject / publish time / affiliation），建立结构化频道模型、arXiv 分类目录与版本化频道偏好持久化，并重做顶部频道栏与「＋」频道管理页，使用户可以添加、删除、排序主题频道并按频道独立浏览。

## 非目标

- 不实现时间筛选入口改造（开发顺序步骤 4）。
- 不实现真实 arXiv 主题查询接入与缓存键 / 分页 / 位置恢复的完整验证（步骤 5）；本任务只建立频道状态容器与 UI，查询接入在后续任务验证。
- 不实现会议数据源端口与真实会议提供方（步骤 6）；会议频道不进入可添加状态。
- 不实现六页阅读结构、中文摘要缓存、PDF AI 解读、相关论文语义检索（步骤 7–10）。
- 不改动 community / messages 模块。

## 验收标准

- [x] `Paper` 领域实体区分 `source`、`venue`、`journalReference`、`affiliation`；单位未知时为空，不以 `arXiv` 或其他占位值填充。
- [x] 未知引用数不以 `0` 冒充真实数据（领域层改为可空未知语义）。
- [ ] arXiv 论文保存并展示 Primary Subject 与全部 Subjects；Subjects 只用于分类索引，不混入内容关键词。（保存已完成；完整展示随六页阅读结构，属后续步骤）
- [x] 频道栏为「文字 + 选中下划线」样式，横向滚动；推荐、关注、最新固定存在；「＋」固定在右侧始终可见。
- [x] 「＋」打开频道管理页，含「按主题」分组与已添加状态；首批主题使用中文显示名并保留真实 arXiv 分类编号（cs.AI / cs.CL / cs.CV / cs.LG）。（主题搜索经编排者决定在目录仅 4 项时暂缓，见决策记录）
- [x] 用户频道支持添加、删除并持久化到版本化本地存储；添加或移除后频道栏与本地配置同步更新。（排序入口经编排者决定移除，频道按目录顺序展示；数据层仍保留顺序）
- [x] 每个频道独立保存论文位置、加载状态和分页状态，互不污染。
- [x] 频道与偏好的持久化结构带 schema 版本与 Migration；旧数据升级测试通过。
- [x] 新增业务行为均有可独立运行的单元 / Widget 测试（频道领域模型、偏好迁移、频道栏与管理页关键流程）。
- [x] `flutter analyze`、`flutter test`、定向格式检查通过。

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

- 已完成：必读文档读取、基线确认、分支与 worktree 创建、台账初始化；步骤 1（`Paper` 元数据语义修正，提交 1b3f8bb）；步骤 2（频道模型、arXiv 主题目录与版本化频道偏好仓储，提交 f2cf901）；步骤 3（频道栏与频道管理页重构，提交 8a103e6）。
- 正在进行：无。
- 下一步：等待编排者决定——开发验收（Windows 桌面运行）、`/test` 完整门禁或继续后续步骤。
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
| 2026-08-04 | 频道栏完全替换旧主题筛选（推荐页临时筛选），频道即索引；浏览位置按频道键独立保存 | 落实开发计划「主题和会议是独立索引」 | `PaperTopicMatcher`、`paper_category_picker.dart` 删除；旧偏好 `topicIndex` 字段保留未用 |
| 2026-08-04 | 频道选中态优先读频道偏好 `selectedChannelKey`，为空时回退旧偏好 `primaryCategoryIndex` | 旧安装无频道偏好文件，保持固定频道选择可恢复 | `initializeChannels` 需在 `initializePreferences` 之后执行 |
| 2026-08-04 | 频道管理页「按会议」区块只展示未开放说明，不提供添加 | 会议频道需真实数据源（步骤 6） | 后续任务接入 `VenueCatalogSource` 后开放 |
| 2026-08-04 | 切换频道只对未加载频道做懒加载，已加载频道不重新请求；强制刷新仅由下拉触发（编排者验收反馈） | 避免每次选 tab 都刷新 | 回归测试覆盖来回切换不重复请求 |
| 2026-08-04 | 频道管理页暂不提供主题搜索，直接列出全部主题（编排者决定） | 目录仅 4 个条目，搜索无价值；目录扩大后再恢复 | `ArxivSubjectCatalog.search/findByCode` 一并移除；合并前需在开发计划建议中同步该调整 |
| 2026-08-04 | 频道管理页「按主题 / 按会议」改为两个 Tab，支持左右滑动翻页（编排者要求） | 分区更清晰，会议页后续可独立扩展 | Widget 测试覆盖滑动翻页 |
| 2026-08-04 | 每个频道保存各自查询加载的论文列表，共享池仅服务关注频道与按 ID 打开（编排者验收反馈） | 不同频道内容不得互相顶替 | 删除全局合并逻辑，新增频道列表独立测试 |
| 2026-08-04 | 双栏点击论文推入详情页（可返回），不再切换单栏模式（编排者验收反馈） | 双栏浏览可中断可恢复 | 未接入详情导航时保留原选中行为 |
| 2026-08-04 | 频道管理主题页只保留主题行对勾状态，移除「已添加频道」区块与拖拽排序（编排者决定） | 对勾足以表达添加状态，减少冗余区块 | 频道按目录顺序展示；数据层顺序能力保留 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter analyze` | 通过（No issues found） | 2026-08-04 |
| `flutter test` | 通过（步骤 1：204；步骤 2：215；步骤 3：218） | 2026-08-04 |
| `tool/verify_changed_dart_format.ps1` | 通过（步骤 3：42 个文件） | 2026-08-04 |

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
| 8a103e6 | feat(papers): rebuild top channel bar and channel manager around structured channels | 步骤 3：频道栏与频道管理页 | analyze 通过；218 测试通过；格式门禁通过 |
| 70d2e5a | fix(papers): only lazy-load channels on first visit instead of refreshing every switch | 验收反馈修复：切换频道不再刷新 | analyze 通过；219 测试通过；格式门禁通过 |
| 28fdf52 | refactor(papers): drop topic search from channel manager while catalog has four entries | 编排者决定：4 个主题无需搜索 | analyze 通过；217 测试通过；格式门禁通过 |
| 415146f | feat(papers): split channel manager into swipeable subject and conference tabs | 编排者要求：按主题/按会议做成 Tab 翻页 | analyze 通过；217 测试通过；格式门禁通过 |
| ab5aed1 | refactor(papers): rename channel manager tabs to 主题/会议 | 编排者要求：Tab 文案去掉「按」字 | analyze 通过；217 测试通过；格式门禁通过 |
| 5928858 | fix(papers): keep a separate loaded feed per channel instead of one shared pool | 验收反馈：不同频道需各自缓存论文列表 | analyze 通过；218 测试通过；格式门禁通过 |
| a40c3a8 | fix(papers): open grid papers in a temporary detail page instead of leaving grid | 验收反馈：双栏点击为临时进入、可返回 | analyze 通过；218 测试通过；格式门禁通过 |
| 85aa8f1 | refactor(papers): rely on topic row checkmarks instead of a separate added-channels list | 编排者决定：对勾即已添加状态 | analyze 通过；218 测试通过；格式门禁通过 |

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
