# 论文关注状态单一事实源重构台账

> 本台账记录 DeepSeek 报告逐步修复链的第五批任务。本批直接基于第四批最终审查提交创建；按编排者要求不合入 `main`，完成后继续作为下一批修复 worktree 的基线。

## 基本信息

- 任务：消除论文 Feed 与互动控制器之间的关注状态双源
- 关联发布或里程碑：代码质量加固，不绑定发布版本
- 分支：`refactor/follow-state-single-source`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-5`
- 基线提交：`fee74bf4008d466e8af716ee6320de6f14a0c9e7`
- 负责人：Codex（Fantasy 编排）
- 状态：规划中
- 最近更新：`2026-08-13 16:38`（Asia/Shanghai）

## 目标

让 `PaperInteractionController` 成为论文关注集合唯一可变事实源，`PaperFeedController` 仅通过只读可监听状态读取并响应变化，删除 Feed 内的 `_followedPaperIds` 镜像和 `PaperController` 的手工集合复制桥；无论关注写入来自兼容 facade、直接互动控制器调用、初始化恢复、重新加载还是持久化失败回滚，关注频道的本地过滤和远程作者查询都自动使用同一份最新状态。

## 非目标

- 不改变“关注作者”的产品语义：新关注仍优先保存规范 `authorKey`，兼容旧的 paper id 关注记录。
- 不修改 `PaperInteractionSnapshot`、互动仓储 schema、JSON mapper、Migration 或已有本地数据。
- 不修改 Paper API `/api/v1/channels/following` 协议、`PaperFeedQuery.followingAuthors` 字段或服务端实现。
- 不重构 `PaperFeedController` 的目录分页、频道偏好、位置记忆、刷新/加载更多重复代码或文件规模；这些属于报告后续粒度问题。
- 不处理报告高危项 #5 的日志与吞异常、`spark_app.dart`、ThemeController 或其他后续问题。
- 不调整论文页 UI、频道文案、空状态、ValueKey 或布局。
- 不启动 Windows App、不做人工验收、不执行浏览器自动化。
- 不合入 `main`，不执行常规 `/finish`，不清理前五个 worktree。

## 验收标准

- [ ] `PaperInteractionController` 是关注集合唯一可变所有者；对外只暴露不可变快照与只读监听契约，调用方不能直接修改集合。
- [ ] `PaperFeedController` 不再声明、复制或替换 `_followedPaperIds` 可变镜像，也不再提供 `setFollowedPaperIds` 手工同步入口；本地过滤、作者参数和空关注加载判断均实时读取唯一来源。
- [ ] `PaperFeedController` 在构造时订阅关注状态、在 `dispose` 时解绑；关注集合变化时仅失效关注频道的目录状态和列表，其他频道不被清空或重新请求。
- [ ] `PaperController` 的装配先创建互动状态源再注入 Feed，并移除 `_handleInteractionsChanged` 集合复制桥；现有 facade 的 like/save/follow/share 通知与释放语义保持。
- [ ] 通过直接调用 `PaperInteractionController`（不经过 `PaperController.toggleFollow`）即可更新当前关注频道、切换后关注频道和远程 `followingAuthors` 查询，证明新增写入路径不依赖额外桥接。
- [ ] 初始化恢复、`reload()` 与持久化失败回滚更新唯一关注状态时，Feed 不保留旧集合；旧 paper id 记录仍可映射首位作者。
- [ ] 新增业务行为有可独立运行的 controller 测试；既有关注过滤、频道刷新、API 查询、互动持久化与页面集成测试保持通过。
- [ ] 相关定向测试、Dart 格式、`flutter analyze`、`flutter test` 与 `git diff --check` 通过。

## 写入范围

### 独占路径

- `lib/src/features/papers/application/paper_controller.dart`
- `lib/src/features/papers/application/paper_feed_controller.dart`
- `lib/src/features/papers/application/paper_interaction_controller.dart`
- 本批如需新增的 papers application 只读关注状态契约文件
- `test/paper_controller_test.dart`
- `test/paper_api_controller_query_test.dart`
- 本批如需新增的关注状态单一来源测试文件
- `docs/workstreams/refactor--follow-state-single-source/status.md`

### 共享路径

- 无。预计不修改组合根、domain/data、Paper API、服务器、presentation 或其他 feature；若证据表明必须扩展，先更新台账再写入。

## 依赖关系

- 上游修复链：第四批 `refactor/chat-screen-boundaries@fee74bf`；本 worktree 完整继承前四批修复与审查证据。
- 重叠历史任务：`qodercn/feature-paper-channels` 确立关注频道本地过滤与频道独立列表；`feature/paper-api-client` 增加远程 `followingAuthors` 查询。两者的现有语义与接口必须保持。
- 外部接口或数据源：无真实外部调用；测试使用内存互动仓储与记录型 `PaperCatalogRepository`。

## 实施计划

1. 用既有关注过滤、互动恢复与 API 查询测试建立基线，新增能绕过 facade 直接改变唯一关注源的红测。
2. 将互动控制器内部关注集合改为不可变快照驱动的专用只读 `ValueListenable`（或等价窄契约），所有 toggle/restore/rollback 统一通过一个替换入口发布变化。
3. 让 Feed 构造时接收并订阅该只读来源，删除可变镜像与 setter；本地投影、远程作者参数和 `_canLoadCurrentChannel` 均读取当前快照。
4. 将 `PaperController` 改为先装配互动控制器、再把同一状态源注入 Feed，删除手工同步 handler，同时保持 facade 对互动和 Feed 通知的兼容行为。
5. 覆盖当前关注频道失效、非关注频道不失效、初始化/重载/回滚和旧 paper id 作者映射；复跑论文 controller、互动、API 与 UI 定向测试。
6. 执行结构检索、格式与静态分析，形成原子代码提交并更新台账；之后依次进入 `/test` 和只读 `/review`，不进入 `/finish`。

## 当前进度

- 已完成：按 `/start` 顺序读取 README、文档索引、开发计划、三份强制规范、DeepSeek 原报告、频道基础与 Paper API Client 重叠台账。
- 已完成：确认报告条目仍成立：`PaperFeedController` 仍持有 `_followedPaperIds` 镜像与 `setFollowedPaperIds`，`PaperController._handleInteractionsChanged()` 仍是唯一集合复制桥，真实写入由 `PaperInteractionController` 完成。
- 已完成：确认本地关注过滤同时兼容 `authorKey` 与旧 paper id；远程关注频道把 `author:*` 或 paper id 映射为小写首位作者，并在关注集合为空时阻止无条件远程请求。
- 已完成：从第四批最终审查提交 `fee74bf` 创建 `agent-5` 与 `refactor/follow-state-single-source`；`main@5578a77` 未变化。
- 正在进行：第五批任务台账初始化，尚未修改功能代码。
- 下一步：触发 `/develop`，先补直接监听来源的边界红测，再按互动唯一源、Feed 订阅、facade 装配顺序实现。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 第五批只处理报告高危项 #4 的关注状态双源 | 该问题可形成独立、可验证、可回滚的应用层结构闭环 | 不顺手清理 Feed 的其他复杂度或日志问题 |
| 2026-08-13 | 互动控制器保持唯一写入权，Feed 只接收只读可监听状态 | Feed 需要过滤和查询关注作者，但不应拥有或替换互动数据 | 新增写入方法、初始化恢复与回滚都会经同一通知源自动传播 |
| 2026-08-13 | 保留 authorKey 与旧 paper id 两类身份兼容 | 现有持久化数据可能仍含旧 paper id；强制迁移不属于本批且会增加数据风险 | Feed 的作者解析和本地过滤语义保持不变 |
| 2026-08-13 | 不进行人工验收或合并 | 编排者明确要求自动修复链保留在 worktree | 以自动化门禁和只读审查作为证据，完成后串联下一 worktree |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `/start` Git 预检 | 控制工作树 `main@5578a77` 干净；第四批 `agent-4@fee74bf` 干净；目标分支与 `agent-5` 路径均不存在 | 2026-08-13 |
| `git worktree add ..\agent-5 -b refactor/follow-state-single-source fee74bf...` | 成功；第五批完整继承前四批修复，`main` 未变化 | 2026-08-13 |
| 报告与源码定向检索 | Feed 可变镜像、公开 setter 和 facade 手工复制桥仍存在；直接互动写入、初始化、reload 与回滚均依赖该桥传播 | 2026-08-13 |
| 重叠历史台账核对 | 锁定频道独立列表、本地 authorKey/paper id 兼容与远程 `followingAuthors` 查询契约 | 2026-08-13 |

## 审查结论

> 尚未进入 `/review`。

- 审查日期：不适用
- 阻断项：待审查
- 缺陷：待审查
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

本批尚未进入实现阶段。目标交付结果为论文关注集合只有一个可变事实源，Feed 通过只读监听自动响应所有互动写入与恢复路径，不再依靠 facade 复制集合；真实结果将在各检查点持续更新。

### 实际变更

- 领域与业务逻辑：预计只调整 papers application 内的状态所有权与订阅，不改变关注语义。
- 数据与基础设施：预计无变化，不修改持久化 schema 或 API。
- 界面与交互：预期无可观察变化。
- 测试与工具：计划新增唯一来源直接写入、恢复和订阅生命周期测试。
- 文档：持续更新本台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：预计只新增 application 内的只读关注状态契约；现有 facade 和服务端查询不变。
- 旧版本兼容性：保留旧 paper id 关注记录解析，无存储格式变化。

### 已知风险与回滚

- 已知风险：订阅时序错误可能导致初始化恢复不刷新关注页、dispose 后回调或一次关注变化重复远程查询；必须由确定性 controller 测试覆盖。
- 回滚方式：按检查点逆序 `git revert`；无数据迁移。

### 文档更新建议

- 本批属于内部状态所有权重构，不预期改变 `docs/development.md` 的功能路线图状态。

### 未完成与后续工作

- 下一批继续处理报告高危项 #5：日志缺失与吞异常；该问题范围较大，应先设计统一诊断边界并分批落地。
- `spark_app.dart`、ThemeController 及中危文件粒度、数据建模、重复代码、死代码、测试缺口和服务端问题继续由后续串联 worktree 处理。

## 合并归档

> 编排者明确要求本修复链不合入 `main`，因此本节当前不适用；不预填集成提交、合并时间或 main 验证。

- 最终状态：未合并，第五批规划中
- 合入分支：不适用
- 最终集成提交：不适用
- Pull Request：不适用
- 合并时间：不适用
- main 集成验证：不适用
- 开发计划更新：本批不改变功能路线图状态
- 最终后续项：完成后以本批最终提交创建下一修复 worktree
