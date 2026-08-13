# 架构边界回归门禁加固台账

> 本台账记录 DeepSeek 报告逐步修复链的第二批任务。本批直接基于第一批最终提交创建；按编排者要求不合入 `main`，完成后继续作为下一批修复 worktree 的基线。

## 基本信息

- 任务：加固架构边界自动化门禁并修正现存 `core` 组件归属
- 关联发布或里程碑：代码质量加固，不绑定发布版本
- 分支：`refactor/architecture-boundary-hardening`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-2`
- 基线提交：`e61d320939fba18b58b489ed99d140b4c84e57aa`
- 负责人：Codex（Fantasy 编排）
- 状态：开发中
- 最近更新：`2026-08-13 14:52`（Asia/Shanghai）

## 目标

让自动化架构门禁能够真实阻止领域层引入基础设施依赖、同一 feature 内逆向跨层依赖、`lib/src` 导入环和不满足跨业务复用条件的 `core` 组件回归，并修正报告指出及新守卫直接暴露的现存同类归属问题。

## 非目标

- 本批不拆分 `paper_ai_message_view.dart`、`paper_ai_chat_screen.dart`、`spark_app.dart` 等大文件；复杂度问题后续单独立项。
- 本批不处理平台调用、关注状态双源、日志体系、领域/存储多职类型、重复 Mapper、服务端推荐和 N+1 查询等相邻问题。
- 不重新设计界面或改变产品交互；组件移动应保持渲染和行为契约不变。
- 不启动 Windows App、不做人工验收、不执行浏览器自动化。
- 不合入 `main`，不执行常规 `/finish`，不清理第一批或本批 worktree。

## 验收标准

- [x] 同 feature 分层守卫覆盖 `presentation -> data`、`application -> data`、`domain -> application/data/presentation` 及其他逆向依赖，并通过隔离 fixture 证明旧盲区会被检出。
- [x] domain 纯净度采用默认拒绝的外部包策略或等价的显式安全允许机制，能够检出 `sqflite`、`path_provider`、`shared_preferences`、`flutter_secure_storage` 等未获准基础设施包以及 `dart:io`。
- [x] `lib/src` 导入图具备循环检测，至少用多文件循环 fixture 验证，并在失败信息中给出可定位的依赖链。
- [ ] `core/widgets` 的业务复用检查以真实 feature 可达性为依据，不把测试或 barrel export 误算为业务复用；少于两个独立业务模块使用的组件会失败或具有明确、可审查的基础设施例外。
- [ ] 报告指出的生产零调用 `CherryButton` 被删除，`ProfileAvatar` 与 `TopicChip` 回归各自业务模块；新守卫发现的其他同类现存问题须修正或记录符合规范的例外理由。
- [ ] 组件移动后的导入、公开入口与测试同步更新，用户可观察行为不变。
- [ ] 架构定向测试、相关 Widget 测试、Dart 格式、`flutter analyze`、`flutter test` 和 `git diff --check` 通过。

## 写入范围

### 独占路径

- `test/architecture_boundaries_test.dart`
- 架构测试所需的 `test/support/` 辅助文件与 fixture
- `lib/src/core/widgets/`
- `lib/src/features/community/presentation/` 中承接头像组件的文件与导入
- `lib/src/features/papers/presentation/` 中承接主题标签组件的文件与导入
- 与上述组件直接对应的测试文件
- `docs/workstreams/refactor--architecture-boundary-hardening/status.md`

### 共享路径

- `lib/spark.dart`：仅在新归属或公开入口核对确有需要时修改，并在提交前单独审查导出影响。

## 依赖关系

- 上游任务：第一批 `fix/report-data-correctness@e61d320`，本 worktree 从其最终审查提交直接创建。
- 外部接口或数据源：无；验证只扫描本地源码并使用临时 fixture。

## 实施计划

1. 将源码扫描、导入解析、分层判定和依赖图检查整理为可对临时源码树运行的测试辅助能力。
2. 先增加能在旧实现上暴露四类盲区的失败 fixture，再实现同 feature 分层、domain 允许策略、循环和 `core` 复用守卫。
3. 删除未使用的 `CherryButton`，将单 feature 组件移回其所有者，并处理新守卫发现的同类现存问题。
4. 运行架构与组件定向回归，形成代码检查点并更新台账。
5. 依次执行 `/test` 与只读 `/review`；按编排者要求保留分支，不进入合并 `main` 的 `/finish`。

## 当前进度

- 已完成：读取 `/start` 工作流及项目必读规范，确认本任务不关联发布版本。
- 已完成：核对报告原文和当前 `architecture_boundaries_test.dart`；确认四项守卫盲区仍成立，当前源码没有同 feature 逆向导入，属于预防未来回归的缺口。
- 已完成：核对 `core/widgets` 使用关系；确认 `CherryButton` 仅测试使用、`ProfileAvatar` 仅 community 使用、`TopicChip` 仅 papers 使用。
- 已完成：从第一批最终提交 `e61d320` 创建 `agent-2` 与 `refactor/architecture-boundary-hardening`，未修改 `main`。
- 已完成：将源码解析和规则判定拆为两个单一职责测试辅助文件；条件 import/export 的所有 URI 均进入依赖图。
- 已完成：以 8 个隔离 fixture 测试补齐同 feature 逆向分层、domain 外部依赖默认拒绝和 `lib/src` 循环诊断，并保留全部既有架构规则；形成 `d8f26ae` 检查点。
- 正在进行：第二批 `/develop`；前三类守卫已完成，`core` 真实业务复用守卫尚待实现。
- 下一步：下一轮 `/develop` 增加 `core/widgets` 可达 feature 规则，删除 `CherryButton` 并移动两个单 feature 组件。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 本批聚焦四类架构守卫与其直接暴露的归属问题 | 四类问题共享同一验收结果：让规范可自动阻止未来回归 | 不把大文件拆分等不同风险混入同一分支 |
| 2026-08-13 | 新规则必须用临时 fixture 自证 | 只扫描当前干净源码无法证明规则真的能发现违规 | 每类盲区至少有一个旧实现会漏报的新回归用例 |
| 2026-08-13 | `core` 复用按 feature 可达性而非文本 import 次数判定 | 内部公共组件可能经其他 core 组件间接服务多个 feature，测试和 barrel export 也不构成真实业务使用 | 降低误报，同时严格落实“至少两个独立业务模块真实使用” |
| 2026-08-13 | 基线使用第一批最终提交 `e61d320` | 编排者要求新的 worktree 基于上一个修复 worktree 构建 | 第二批完整继承第一批修复，`main@5578a77` 保持不变 |
| 2026-08-13 | 不进行人工验收或合并 | 编排者明确要求自动修复链保留在 worktree | 以自动化测试和只读审查作为本批证据 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `/start` Git 预检 | 控制工作树 `main@5578a77` 干净；第一批 `agent-1@e61d320` 干净；目标分支不存在 | 2026-08-13 |
| `git worktree add ..\agent-2 -b refactor/architecture-boundary-hardening e61d320...` | 成功；`agent-2` 当前 HEAD 为第一批最终提交，`main` 未变化 | 2026-08-13 |
| 报告与源码定向检索 | 四类架构盲区仍成立；三个报告所列 `core` 归属问题仍成立；当前同 feature 逆向导入为 0 | 2026-08-13 |
| `flutter test test/architecture_test_support_test.dart test/architecture_boundaries_test.dart` | 17 项全部通过；8 项 fixture 覆盖违规与合法方向、插件包、内部非 domain、显式允许包、循环与条件 import | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过；7 个当前改动 Dart 文件均无需格式化 | 2026-08-13 |
| `flutter analyze` | `No issues found` | 2026-08-13 |
| `git diff --cached --check` 与敏感信息检查 | 通过；代码检查点只含 5 个架构测试文件 | 2026-08-13 |
| 人工验收 | 按编排者明确指示不运行 | 2026-08-13 |

## 审查结论

- 审查日期：待 `/review`
- 阻断项：待 `/review`
- 缺陷：待 `/review`
- 结论：待 `/review`

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `d8f26ae` | `测试（架构）：补齐依赖边界回归门禁` | `/develop` 第一轮 | 架构定向 17 项、格式门禁和 `flutter analyze` 通过 |

## 交付准备（合并前收集）

### 交付摘要

待 `/develop`、`/test` 与 `/review` 完成后补充。本任务按编排者要求不合入 `main`。

### 实际变更

- 领域与业务逻辑：待实现。
- 数据与基础设施：待实现。
- 界面与交互：计划仅移动组件归属，不改变行为。
- 测试与工具：已实现前三类可由 fixture 自证的架构守卫；`core` 复用守卫待下一轮完成。
- 文档：持续更新本台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：预计无；若实现中发生则据实更新。
- 旧版本兼容性：预计无影响。

### 已知风险与回滚

- 已知风险：架构扫描若只依赖文件级启发式可能误判符号复用，开发阶段须用当前全量源码与反例 fixture 双向验证。
- 回滚方式：本批形成检查点后记录精确 revert 顺序；无数据迁移。

### 文档更新建议

- 本批属于工程门禁加固，不预期改变 `docs/development.md` 的功能路线图状态。

### 未完成与后续工作

- 报告中的大文件、状态双源、日志、建模、重复代码、死模块、测试缺口与服务端问题继续由后续串联 worktree 处理。

## 合并归档

> 编排者明确要求本修复链不合入 `main`，因此本节当前不适用；不预填集成提交、合并时间或 main 验证。

- 最终状态：未合并，修复链开发中
- 合入分支：不适用
- 最终集成提交：不适用
- Pull Request：不适用
- 合并时间：不适用
- main 集成验证：不适用
- 开发计划更新：本批不改变功能路线图状态
- 最终后续项：完成后继续以本批最终提交为下一修复 worktree 基线
