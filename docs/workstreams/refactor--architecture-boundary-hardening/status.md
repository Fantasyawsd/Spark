# 架构边界回归门禁加固台账

> 本台账记录 DeepSeek 报告逐步修复链的第二批任务。本批直接基于第一批最终提交创建；按编排者要求不合入 `main`，完成后继续作为下一批修复 worktree 的基线。

## 基本信息

- 任务：加固架构边界自动化门禁并修正现存 `core` 组件归属
- 关联发布或里程碑：代码质量加固，不绑定发布版本
- 分支：`refactor/architecture-boundary-hardening`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-2`
- 基线提交：`e61d320939fba18b58b489ed99d140b4c84e57aa`
- 负责人：Codex（Fantasy 编排）
- 状态：待重新审查（第二次审查阻断修复后的 `/test` 已通过）
- 最近更新：`2026-08-13 15:36`（Asia/Shanghai）

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
- [x] `core/widgets` 的业务复用检查以真实 feature 可达性为依据，不把测试或 barrel export 误算为业务复用；少于两个独立业务模块使用的组件会失败或具有明确、可审查的基础设施例外。
- [x] 报告指出的生产零调用 `CherryButton` 被删除，`ProfileAvatar` 与 `TopicChip` 回归各自业务模块；新守卫发现的其他同类现存问题须修正或记录符合规范的例外理由。
- [x] 组件移动后的导入、公开入口与测试同步更新，用户可观察行为不变。
- [x] 架构定向测试、相关 Widget 测试、Dart 格式、`flutter analyze`、`flutter test` 和 `git diff --check` 通过。

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
6. 审查阻断闭环：以单级与多级 feature barrel 的真实 importer 正例暴露假阳性，改用带 import/export 类型的反向边；export 只透传，import 才计为业务使用。

## 当前进度

- 已完成：读取 `/start` 工作流及项目必读规范，确认本任务不关联发布版本。
- 已完成：核对报告原文和当前 `architecture_boundaries_test.dart`；确认四项守卫盲区仍成立，当前源码没有同 feature 逆向导入，属于预防未来回归的缺口。
- 已完成：核对 `core/widgets` 使用关系；确认 `CherryButton` 仅测试使用、`ProfileAvatar` 仅 community 使用、`TopicChip` 仅 papers 使用。
- 已完成：从第一批最终提交 `e61d320` 创建 `agent-2` 与 `refactor/architecture-boundary-hardening`，未修改 `main`。
- 已完成：将源码解析和规则判定拆为两个单一职责测试辅助文件；条件 import/export 的所有 URI 均进入依赖图。
- 已完成：以 8 个隔离 fixture 测试补齐同 feature 逆向分层、domain 外部依赖默认拒绝和 `lib/src` 循环诊断，并保留全部既有架构规则；形成 `d8f26ae` 检查点。
- 已完成：新增 `core/widgets` 反向可达 feature 守卫；隔离 fixture 证明 core 包装器可透传真实使用，而测试导入和无人使用的 barrel 不计数。
- 已完成：新守卫在修复前准确报告 `ProfileAvatar`、`TopicChip` 和 `SparkThemeSheet` 三项单 feature 归属；三者已移回 community、papers 和 profile。
- 已完成：删除生产零调用的 `CherryButton` 及专用测试，保留仍有真实调用的 `CherryIconButton` 和 `CherrySurface`；形成 `6fc6a73` 检查点。
- 已完成：`/test` 完整门禁通过；20 个 Dart 文件格式、静态分析、461 项 Flutter 测试、55 项服务端测试、Python 编译与 Git 检查均成功。
- 已完成：`/review` 审查批准基线 `e61d320...e3a8ac6` 的 5 个提交、19 个文件和全部验收标准，发现 1 个 core 复用守卫假阴性。
- 已完成：新增两个 feature barrel 只 export 同一 core widget 的失败 fixture；旧实现返回 0 违规，新实现正确报告 `features: none`。
- 已完成：源码图暴露 typed imports；core 复用图只将 feature import 计为使用，core import/export 均可继续内部可达性追踪；形成 `4743ded` 检查点。
- 已完成：审查阻断修复后的 `/test` 完整门禁通过；20 个 Dart 文件格式、静态分析、462 项 Flutter 测试、55 项服务端测试、Python 编译与 Git 检查均成功。
- 已完成：重新 `/review` 确认原“feature barrel 仅 export 即伪造复用”的假阴性已修复，且逐项核对 19 个改动文件与全部结构阻断条件。
- 已完成：新增单级 papers barrel 与多级 chat barrel 均被真实 presentation 页面 import 的合法 fixture；修复前精确误报 `features: none`。
- 已完成：分别建立 import/export 反向边；export 只将 exporter 加入待遍历集合，import 才把 importer 所属 feature 计为真实消费者，同时保留 core wrapper 透传；形成 `db35c03` 检查点。
- 已完成：修复后 23 项架构测试、20 文件格式门禁和 `flutter analyze` 通过。
- 已完成：第二次审查阻断修复后的 `/test` 完整门禁通过；20 文件格式、静态分析、463 项 Flutter 测试、55 项服务端测试、Python 编译与 Git 一致性检查均成功。
- 正在进行：最终代码与完整验证证据已就绪，等待重新执行只读 `/review`。
- 下一步：触发 `/review`，复核 `e61d320` 至当前任务 tip，重点确认 feature barrel 的假阴性与假阳性均已闭环。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 本批聚焦四类架构守卫与其直接暴露的归属问题 | 四类问题共享同一验收结果：让规范可自动阻止未来回归 | 不把大文件拆分等不同风险混入同一分支 |
| 2026-08-13 | 新规则必须用临时 fixture 自证 | 只扫描当前干净源码无法证明规则真的能发现违规 | 每类盲区至少有一个旧实现会漏报的新回归用例 |
| 2026-08-13 | `core` 复用按 feature 可达性而非文本 import 次数判定 | 内部公共组件可能经其他 core 组件间接服务多个 feature，测试和 barrel export 也不构成真实业务使用 | 降低误报，同时严格落实“至少两个独立业务模块真实使用” |
| 2026-08-13 | 基线使用第一批最终提交 `e61d320` | 编排者要求新的 worktree 基于上一个修复 worktree 构建 | 第二批完整继承第一批修复，`main@5578a77` 保持不变 |
| 2026-08-13 | 不进行人工验收或合并 | 编排者明确要求自动修复链保留在 worktree | 以自动化测试和只读审查作为本批证据 |
| 2026-08-13 | 将新守卫额外发现的 `SparkThemeSheet` 移回 profile | 根 barrel export 不构成两个业务模块真实使用；该面板只有 profile 生产调用 | 移除 `spark.dart` 中对应展示实现导出，测试改为导入 profile 所有者路径 |
| 2026-08-13 | import 与 export 使用独立反向边语义 | export 只能证明 API 可达，不能证明业务使用；但必须保留才能穿过被真实 import 的 barrel | export 只透传遍历，import 才计 feature，兼顾无人使用 barrel 反例与单级/多级真实 importer 正例 |

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
| `flutter test test/architecture_boundaries_test.dart`（core 归属修复前） | 按预期失败并精确列出 `ProfileAvatar -> community`、`SparkThemeSheet -> profile`、`TopicChip -> papers` 三项 | 2026-08-13 |
| `flutter test test/architecture_test_support_test.dart test/architecture_boundaries_test.dart test/cherry_primitives_test.dart test/spark_theme_test.dart test/ui_preview_test.dart` | 修复后 56 项全部通过；覆盖守卫反例、真实源码、主题交互、动效令牌和跨模块导航/展示 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1`（第二轮） | 通过；20 个当前任务 Dart 文件均无需格式化 | 2026-08-13 |
| `flutter analyze`（第二轮） | `No issues found` | 2026-08-13 |
| 删除符号与旧路径全量检索 | `CherryButton*`、`showSparkThemeSheet` 和三个旧 `core/widgets` 路径均为 0 引用 | 2026-08-13 |
| `/test` `.\tool\verify_changed_dart_format.ps1` | 通过；20 个任务相关 Dart 文件，0 个需格式化 | 2026-08-13 |
| `/test` `flutter analyze` | `No issues found` | 2026-08-13 |
| `/test` `flutter test` | 461 项全部通过 | 2026-08-13 |
| `/test` `$env:PYTHONPATH=(Resolve-Path server).Path; python -m unittest discover -s server/tests -v` | 串联基线的 55 项服务端测试全部通过 | 2026-08-13 |
| `/test` `python -m compileall -q server` | 通过 | 2026-08-13 |
| `/test` `git diff --check`、`git diff --cached --check` 与工作区检查 | 通过；验证前后任务 worktree 干净，Flutter 生成文件内容未变化 | 2026-08-13 |
| `/test` 目标构建 | 按阶段规范不运行；APK 与 Windows release 构建属于常规 `/finish` 合入 `main` 后门禁，本修复链明确不合入 `main` | 2026-08-13 |
| `/test` 人工验收 | 按编排者明确指示不运行；本批不改变可观察交互 | 2026-08-13 |
| feature barrel 新增 fixture（修复前） | 按预期失败：旧实现返回空违规列表，证明两个 feature export 可伪造复用 | 2026-08-13 |
| `flutter test test/architecture_test_support_test.dart test/architecture_boundaries_test.dart`（审查修复后） | 22 项全部通过；feature barrel export 报告 `features: none`，core 内部包装器仍可正确透传两个真实 feature import | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1`（审查修复后） | 通过；20 个任务相关 Dart 文件均无需格式化 | 2026-08-13 |
| `flutter analyze`（审查修复后） | `No issues found` | 2026-08-13 |
| `/test` `.\tool\verify_changed_dart_format.ps1`（审查修复后完整复测） | 通过；20 个任务相关 Dart 文件，0 个需格式化 | 2026-08-13 |
| `/test` `flutter analyze`（审查修复后完整复测） | `No issues found` | 2026-08-13 |
| `/test` `flutter test`（审查修复后完整复测） | 462 项全部通过，退出码 0 | 2026-08-13 |
| `/test` `$env:PYTHONPATH=(Resolve-Path server).Path; python -m unittest discover -s server/tests -v`（审查修复后完整复测） | 55 项服务端测试全部通过 | 2026-08-13 |
| `/test` `python -m compileall -q server`（审查修复后完整复测） | 通过 | 2026-08-13 |
| `/test` Git 一致性检查（审查修复后完整复测） | `git diff --check`、`git diff --cached --check` 通过；工作树与暂存区为空；`main` 仍为 `5578a77` | 2026-08-13 |
| `/test` 目标构建（审查修复后完整复测） | 按阶段规范不运行；本修复链明确不合入 `main`，不会进入常规 `/finish` 构建门禁 | 2026-08-13 |
| `/test` 人工验收（审查修复后完整复测） | 按编排者明确指示不运行；以自动化回归与只读审查作为验收证据 | 2026-08-13 |
| 重新 `/review` `flutter test test/architecture_test_support_test.dart test/architecture_boundaries_test.dart` | 现有 22 项全部通过；未覆盖 feature barrel 被真实页面 import 的合法透传正例，不能证明真实可达性完整 | 2026-08-13 |
| 重新 `/review` 全量差异与结构检查 | 已核对 `e61d320...19e6a7a` 的 9 个提交、19 个文件及全部阻断条件；除 core 复用图假阳性外未发现其他缺陷 | 2026-08-13 |
| 重新 `/review` Git 状态 | `git diff --check` 通过，任务 worktree 干净；`main@5578a77` 未变化 | 2026-08-13 |
| feature barrel 真实 importer fixture（修复前） | 按预期失败：合法的 papers 单级与 chat 多级 barrel 使用链被误报为 `lib/src/core/widgets/shared.dart -> features: none` | 2026-08-13 |
| `flutter test test/architecture_test_support_test.dart --plain-name 'counts real feature use through imported feature barrels'`（修复后） | 1 项通过 | 2026-08-13 |
| `flutter test test/architecture_test_support_test.dart test/architecture_boundaries_test.dart`（第二次审查修复后） | 23 项全部通过；同时覆盖 core wrapper、无人 import 的 core/feature barrel、单级和多级真实 feature importer | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1`（第二次审查修复后） | 首次只读检查发现 `architecture_rules.dart` 需格式化；显式格式化后复检通过，20 个任务相关 Dart 文件 0 变化 | 2026-08-13 |
| `flutter analyze`（第二次审查修复后） | `No issues found` | 2026-08-13 |
| `git diff --check` 与敏感信息检查（第二次审查修复后） | 通过；代码提交只含规则和 fixture，未发现敏感信息 | 2026-08-13 |
| `/test` `.\tool\verify_changed_dart_format.ps1`（第二次审查修复后完整复测） | 通过；20 个任务相关 Dart 文件，0 个需格式化 | 2026-08-13 |
| `/test` `flutter analyze`（第二次审查修复后完整复测） | `No issues found` | 2026-08-13 |
| `/test` `flutter test`（第二次审查修复后完整复测） | 463 项全部通过，退出码 0 | 2026-08-13 |
| `/test` `$env:PYTHONPATH=(Resolve-Path server).Path; python -m unittest discover -s server/tests -v`（第二次审查修复后完整复测） | 55 项服务端测试全部通过 | 2026-08-13 |
| `/test` `python -m compileall -q server`（第二次审查修复后完整复测） | 通过 | 2026-08-13 |
| `/test` Git 一致性检查（第二次审查修复后完整复测） | 全任务与工作树 `git diff --check`、暂存区检查通过；验证后工作树和暂存区为空；`main` 仍为 `5578a77` | 2026-08-13 |
| `/test` 目标构建（第二次审查修复后完整复测） | 按阶段规范不运行；本修复链明确不合入 `main`，不会进入常规 `/finish` 构建门禁 | 2026-08-13 |
| `/test` 人工验收（第二次审查修复后完整复测） | 按编排者明确指示不运行；以自动化回归与只读审查作为验收证据 | 2026-08-13 |

## 审查结论

- 审查日期：2026-08-13（重新审查）
- 审查范围：`e61d320939fba18b58b489ed99d140b4c84e57aa...19e6a7a90ab822a323fbf00b73b4ed2fc1be871d`；9 个提交、19 个文件，新增 1019 行、删除 387 行。
- 基线说明：`origin/main@948f3af` 比当前修复链落后 89 个提交；按编排者批准的上一批最终提交 `e61d320` 固定本批范围，避免混入第一批或无关历史。
- 规格核对：同 feature 分层、domain 纯净度、循环检测、组件迁移/删除、行为保持和完整验证 6 项满足；core 真实复用可达性 1 项未满足。
- 结构核对：逐项检查 19 个改动文件；未触发 Widget/Controller 基础设施直连、领域层外部依赖、多职数据类型、core 反向依赖、循环依赖、业务 utils、深继承、超大页面新增流程或只能依赖完整 UI 验证等其他阻断条件。
- 已闭环的原阻断项：`4743ded` 使两个 feature 仅 export 同一 core widget 时不再被计为真实使用，原假阴性已由 fixture 覆盖。
- 新阻断项：`test/support/architecture_rules.dart:145-176` 只保留 feature 的 import，完全不建立 feature export 的反向透传边。若 `papers.dart` 与 `chat.dart` 各自 export 同一 core widget，且各自 presentation 页面真实 import 对应 barrel，算法仍无法从 widget 到达这些页面并会误报 `features: none`。`test/architecture_test_support_test.dart:212-227` 仅覆盖“无人 import 的 feature barrel 不计数”，缺少“被真实 import 后应计数”的合法正例。
- 修复方向：反向依赖图保留 import/export 边类型；遇到 export 只进入 exporter 继续遍历而不计 feature，遇到 import 才把 importer 所属 feature 记为真实使用，并覆盖多级 barrel、无人 import barrel 与两个真实 importer 三类 fixture。
- 修复状态：`db35c03` 已按上述方向实现，修复前 fixture 精确失败，修复后 23 项架构定向测试与包含 463 项 Flutter、55 项服务端测试的完整 `/test` 均通过；待重新 `/review` 更新最终结论。
- 缺陷：除上述阻断项外未发现其他缺陷或建议项。
- `/test` 证据：格式、`flutter analyze`、462 项 Flutter 测试、55 项服务端测试、Python 编译与 Git 检查均通过；重新审查时 22 项架构定向测试再次通过，但现有集合未覆盖上述合法 barrel 透传路径。
- 未验证项：按阶段未执行目标构建；按编排者要求未进行人工验收；两项均不是本次审查阻断原因。
- 结论：重新审查当时要求返回 `/develop`；代码阻断与完整 `/test` 现已闭环，但完成重新 `/review` 前仍不得作为下一串联 worktree 基线。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `d8f26ae` | `测试（架构）：补齐依赖边界回归门禁` | `/develop` 第一轮 | 架构定向 17 项、格式门禁和 `flutter analyze` 通过 |
| `6fc6a73` | `重构（架构）：校正公共组件业务归属` | `/develop` 第二轮 | 架构/主题/UI 等定向 56 项、格式门禁和 `flutter analyze` 通过 |
| `4743ded` | `修复（架构）：排除 feature barrel 伪复用` | `/develop` 审查修复 | 新增 fixture 修复前准确失败；修复后架构 22 项、格式和 `flutter analyze` 通过 |
| `db35c03` | `修复（架构）：透传 barrel 真实复用` | `/develop` 第二次审查修复 | 合法 fixture 修复前准确失败；修复后架构 23 项、格式和 `flutter analyze` 通过 |

## 交付准备（合并前收集）

### 交付摘要

同 feature 分层、domain 纯净度、循环检测和现存组件归属问题已修复；两轮 `/review` 发现的 feature barrel 假阴性与真实 import 链假阳性均已由 fixture 驱动修复，第二次审查修复后的完整 `/test` 已通过，当前等待重新 `/review`。本任务按编排者要求不合入 `main`。

### 实际变更

- 领域与业务逻辑：无行为变化；仅强化依赖方向和组件所有权约束。
- 数据与基础设施：无变化。
- 界面与交互：头像、主题标签和主题面板只移动文件归属；主题面板入口及交互保持不变；删除无生产入口的 `CherryButton`。
- 测试与工具：四类架构守卫均由隔离 fixture 自证；core 复用同时覆盖 core 内部转发、单 feature、测试导入、无人使用 core/feature barrel、单级与多级 feature barrel 真实 importer。
- 文档：持续更新本台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：`spark.dart` 不再导出仅供 profile 使用的 `showSparkThemeSheet`；内部入口更名为 `showProfileThemeSheet` 并由 profile 直接引用。领域契约无变化。
- 旧版本兼容性：项目尚未正式发布，仓库内全部调用已同步；无数据或运行时迁移。

### 已知风险与回滚

- 已知风险：core 复用规则按文件级依赖判定，单个共享文件内部未来新增的未使用公开符号仍需 analyzer、引用检索和审查共同发现。
- 回滚方式：按逆序 `git revert db35c03 4743ded 6fc6a73 d8f26ae`；无数据迁移。

### 文档更新建议

- 本批属于工程门禁加固，不预期改变 `docs/development.md` 的功能路线图状态。

### 未完成与后续工作

- 报告中的大文件、状态双源、日志、建模、重复代码、死模块、测试缺口与服务端问题继续由后续串联 worktree 处理。

## 合并归档

> 编排者明确要求本修复链不合入 `main`，因此本节当前不适用；不预填集成提交、合并时间或 main 验证。

- 最终状态：未合并，完整复测通过，待重新审查
- 合入分支：不适用
- 最终集成提交：不适用
- Pull Request：不适用
- 合并时间：不适用
- main 集成验证：不适用
- 开发计划更新：本批不改变功能路线图状态
- 最终后续项：完成后继续以本批最终提交为下一修复 worktree 基线
