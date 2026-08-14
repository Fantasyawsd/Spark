# 应用壳边界重构任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 1. 任务信息

| 项目 | 内容 |
| --- | --- |
| 目标 | 将 Spark 应用组合根拆为职责清晰、可独立验证的依赖解析、主题/App 壳、闪屏、运行期控制器所有权与导航展示边界；消除重复 preview 装配和依赖参数层层转发，同时保持生命周期、导航、功能开关及用户行为不变。 |
| 非目标 | 不修改领域模型、数据契约、缓存格式、远程 API、页面视觉与交互；不处理全局 `ThemeController`（留给后续独立任务）；不合入 `main`，不进行人工桌面验收。 |
| 验收标准 | 见下文“验收标准”。 |
| 分支 | `refactor/app-shell-boundaries` |
| worktree | `C:\Users\Fantasy\Desktop\Spark-worktrees\agent-7` |
| 基线 | `5e4dd9c2a65a9e9230c83990a8dd7c309a5da30a`（上一批 `fix/runtime-diagnostics` 最终审查提交） |
| 负责人 | Fantasy（编排）；Codex（执行） |
| 当前阶段 | `/review` 已完成；下一步基于最终审查提交创建新的串行 worktree |

## 2. 问题与边界

DeepSeek 报告指出 `lib/src/app/spark_app.dart` 同时承担应用根、闪屏、导航壳和跨控制器编排，形成“上帝壳”。基线实测该文件为 781 行、6 个类；`SparkApp` 与 `SparkShell` 重复展开一组仓储/服务覆盖参数，`_SparkShellState` 还会再次调用 `SparkDependencies.preview(...)`，并直接创建、初始化和销毁整组运行期控制器。

本任务只调整应用层组合与生命周期边界，不改变下列既有契约：

- `ChatConversationCoordinator` 仍由应用根生命周期持有，跨页面导航继续存活，并在会话删除、本地聊天清理及根销毁时正确取消或移除任务。
- `_linkService.open` 继续注入主页 Chat、论文 Chat 与论文详情 Chat 三条入口。
- 论文、ChatPaper、我的三个一级页面及 community 功能开关行为不变。
- preview 与生产依赖选择、闪屏键值/动效/图片/无障碍降级、导航与返回栈行为不变。
- 本地数据清理前后的控制器停写、清理、重载顺序，以及论文书架、搜索、详情和 Chat 上下文刷新行为不变。

## 3. 验收标准

1. `spark_app.dart` 只保留 `MaterialApp`、主题与根节点装配职责，闪屏、导航壳和运行期控制器所有权迁出，文件降至不超过 180 行。
2. 闪屏拥有独立应用层文件和聚焦测试；现有 value key、动效时序、`disableAnimations` 降级、图片与遮罩行为保持不变。
3. 非空 `SparkDependencies` 只在应用根解析一次；应用生产源码中仅根节点允许调用一次 `SparkDependencies.preview(...)`，`SparkShell` 不再包含 fallback。
4. `SparkApp` 不再镜像转发各仓储/服务覆盖参数；其公开构造参数仅保留 `key`、`config`、`showSplash`、`dependencies`。`SparkShell` 构造参数仅保留 `key`、必需的 `dependencies` 与可选/默认的 `features`。
5. 新的应用运行期会话对象集中创建、初始化和销毁控制器，保留当前初始化顺序、异步任务取消语义与本地数据清理编排；`SparkShell` 状态本身不再创建或销毁控制器群。
6. 导航展示、论文书架/搜索/详情、主页与论文 Chat、设置与本地数据路径保持现有行为；不产生数据迁移、API 或领域层变更。
7. 增加结构回归测试，防止重复 preview fallback、构造参数面重新膨胀和应用壳职责回流，并以现有应用壳、导航、Chat 后台完成及闪屏测试覆盖行为契约。
8. `/test` 阶段的格式检查、`flutter analyze`、`flutter test` 全部通过；按用户指示不进行人工验收，也不合入 `main`。

## 4. 写入范围

### 独占写入

- `lib/src/app/spark_app.dart`
- `lib/src/app/spark_bootstrap.dart`（计划新增）
- `lib/src/app/spark_shell.dart`（计划新增）
- `lib/src/app/spark_application_session.dart`（计划新增，最终名称可在实现阶段按职责校准）
- `test/app_shell_boundaries_test.dart`（计划新增）
- `docs/workstreams/refactor--app-shell-boundaries/status.md`

### 共享或可能调整

- `lib/spark.dart`：仅在维持公共导出兼容性确有需要时调整。
- `test/chat_background_completion_test.dart`、`test/ui_preview_test.dart`：迁移直接构造 `SparkShell` 的测试装配。
- 其他直接构造 `SparkApp` 并使用仓储/服务覆盖参数的应用、导航和功能开关测试：只做 `SparkDependencies.preview(...)` 装配迁移，不扩大行为修改。

### 禁止顺手修改

- feature、domain、data 层业务实现与数据契约。
- 全局主题控制器设计。
- community 或旧 messages 的产品范围。
- 与本任务无关的格式化和重构。

## 5. 实施计划

1. 增加现状刻画与结构测试，锁定依赖解析次数、构造参数面、闪屏和关键生命周期契约。
2. 抽离闪屏/bootstrap 边界，使应用根只负责主题和顶层装配。
3. 引入应用运行期会话对象，集中持有控制器、服务别名及初始化/销毁/本地清理编排。
4. 抽离导航展示壳，并将 `SparkShell` 改为只接收完整依赖和功能开关。
5. 迁移测试装配与公共导出，执行定向测试和结构搜索；随后进入 `/test` 与 `/review`。

### 当前迭代：闪屏/bootstrap 边界

- 改动文件：`lib/src/app/spark_app.dart`、新增 `lib/src/app/spark_bootstrap.dart`、新增 `test/app_shell_boundaries_test.dart`，以及本台账。
- 闭环目标：把启动动画与 `SparkShell` 叠放逻辑完整迁出 `spark_app.dart`，不改变 `SparkApp`、`SparkShell` 构造接口和运行行为。
- 验证：结构测试确认 bootstrap 类及 splash key 不再位于 `spark_app.dart`；`test/widget_test.dart` 验证普通动画、reduce-motion 与导航行为；随后运行 `flutter analyze` 和变更 Dart 格式检查。

### 当前迭代：应用运行期会话边界

- 改动文件：新增 `lib/src/app/spark_application_session.dart`，调整 `lib/src/app/spark_app.dart`、`test/app_shell_boundaries_test.dart` 与本台账。
- 闭环目标：由 `SparkApplicationSession` 统一创建、初始化、同步和销毁根级控制器，并封装 Chat 清理与本地业务数据重载；`SparkShell` 状态仅持有和监听一个会话对象。
- 保留边界：路由级 `PaperSearchController` 仍由对应路由创建和销毁；导航、页面构造与依赖 fallback 本轮不迁移，分别留给后续导航壳及依赖入口迭代。
- 验证：源码边界测试禁止七类根控制器重新回流 `spark_app.dart`；运行 `test/app_shell_boundaries_test.dart`、`test/chat_background_completion_test.dart`、`test/widget_test.dart`，随后执行 `flutter analyze` 和变更 Dart 格式检查。

### 当前迭代：导航展示壳边界

- 改动文件：新增 `lib/src/app/spark_shell.dart`，调整 `lib/src/app/spark_app.dart`、`test/app_shell_boundaries_test.dart` 与本台账。
- 闭环目标：将 `SparkShell`、一级页面装配、书架/搜索/详情/Chat 路由和覆盖层导航状态整体迁出应用根；`spark_app.dart` 只保留 `SparkApp`、主题、依赖解析和 bootstrap 装配。
- 兼容性：`spark_app.dart` 转导出 `SparkShell`，让 `package:spark/spark.dart` 和现有 `package:spark/src/app/spark_app.dart` 导入路径继续可见该类型。
- 保留边界：本轮不改变 `SparkApp`/`SparkShell` 构造参数，也不消除第二次 preview fallback；依赖入口与测试装配在下一迭代统一迁移。
- 验证：源码边界测试确认导航页面、路由构造和 `SparkShell` 类不再位于 `spark_app.dart`，并验证两条公开导入路径；运行应用壳、Chat 后台完成、UI preview 与 Widget 导航测试，再执行 `flutter analyze` 和变更 Dart 格式检查。

### 当前迭代：依赖入口收口

- 改动文件：`lib/src/app/spark_app.dart`、`lib/src/app/spark_shell.dart`、`test/app_shell_boundaries_test.dart`，以及所有直接通过 `SparkApp`/`SparkShell` 镜像参数注入测试替身的应用壳测试与本台账。
- 闭环目标：`SparkApp` 只保留 `key`、`config`、`showSplash`、`dependencies`；`SparkShell` 只保留 `key`、必需的 `dependencies` 与默认 `features`；完整依赖只在根节点解析一次，导航壳不再创建 preview fallback。
- 迁移方式：测试替身统一通过 `SparkDependencies.preview(...)` 组装完整依赖，不改变测试数据、替身实例或断言。
- 验证：扩展源码边界测试锁定两个构造参数面、禁止 `spark_shell.dart` 调用 preview，并确认应用生产源码只剩一个 `SparkDependencies.preview(...)`；运行应用壳、Chat 后台完成、Widget、UI preview、功能开关、键盘窗口及主壳定向测试，再执行 `flutter analyze` 和变更 Dart 格式检查。

## 6. 决策记录

| 时间 | 决策 | 原因 |
| --- | --- | --- |
| 2026-08-13 | 从上一批最终审查提交 `5e4dd9c2` 串行创建新 worktree，而非从 `main` 开始。 | 遵循用户要求，让后续修复累计包含此前全部已审查改动，同时保持 `main` 不变。 |
| 2026-08-13 | 将全局 `ThemeController` 排除在本任务之外。 | 报告将其列为独立问题；本批只治理应用壳职责和生命周期，避免两个结构性改动耦合。 |
| 2026-08-13 | 运行期控制器所有权迁入专用应用会话对象，而不是下沉到页面。 | Chat 后台任务必须跨页面存活，组合根仍应统一掌握其生命周期。 |
| 2026-08-13 | 测试覆盖参数统一经 `SparkDependencies.preview(...)` 构造完整依赖。 | 消除 `SparkApp`/`SparkShell` 重复参数面和第二次 fallback，同时保留测试替身能力。 |
| 2026-08-13 | 路由级 `PaperSearchController` 暂留导航壳就地创建和销毁。 | 它的生命周期只覆盖搜索路由，不属于应用会话；本轮不把短生命周期对象提升为根级所有权。 |
| 2026-08-13 | 由 `spark_app.dart` 转导出 `SparkShell`，暂不修改 `lib/spark.dart`。 | 保持公开包入口及既有内部导入路径兼容，同时避免公共出口重复声明。 |

## 7. 验证记录

| 时间 | 阶段 | 命令或检查 | 结果 |
| --- | --- | --- | --- |
| 2026-08-13 | `/start` | 控制工作树分支、状态、diff、最近提交与 worktree 列表预检 | `main` 干净，保持在 `5578a77d`。 |
| 2026-08-13 | `/start` | 上游 `agent-6` 分支、状态与 HEAD 核验 | `fix/runtime-diagnostics` 干净，最终审查提交为 `5e4dd9c2a65a9e9230c83990a8dd7c309a5da30a`。 |
| 2026-08-13 | `/start` | `git worktree add ..\agent-7 -b refactor/app-shell-boundaries 5e4dd9c2...` | 成功；路径、分支与串行基线符合规范。 |
| 2026-08-13 | `/start` | 报告、强制文档、模板及重叠台账核对 | 已完成；确认本任务延续此前显式延期的 `spark_app.dart` 拆分，并保留 Chat 协调器应用根生命周期契约。 |
| 2026-08-13 | `/develop` 迭代 1 | `flutter test test\app_shell_boundaries_test.dart test\widget_test.dart` | 通过，8 项测试覆盖独立 bootstrap、启动动画、reduce-motion、一级导航与功能开关。 |
| 2026-08-13 | `/develop` 迭代 1 | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 | `/develop` 迭代 1 | `.\tool\verify_changed_dart_format.ps1` | 首次因 `pub get` 前格式化未加载 package 配置而发现 1 个文件差异；重新格式化后通过，共检查 94 个变更相关 Dart 文件。 |
| 2026-08-13 | `/develop` 迭代 2 | `flutter test test\app_shell_boundaries_test.dart test\chat_background_completion_test.dart test\widget_test.dart` | 通过，16 项测试覆盖会话所有权边界、根协调器销毁、后台回复存活、会话删除、Chat 数据清理、闪屏与一级导航。 |
| 2026-08-13 | `/develop` 迭代 2 | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 | `/develop` 迭代 2 | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 95 个变更相关 Dart 文件。 |
| 2026-08-13 | `/develop` 迭代 3 | `flutter test test\app_shell_boundaries_test.dart test\chat_background_completion_test.dart test\widget_test.dart test\ui_preview_test.dart` | 通过，45 项测试覆盖导航壳结构、两条导入路径、书架/搜索/详情、主页与论文 Chat、后台完成和会话操作。 |
| 2026-08-13 | `/develop` 迭代 3 | `flutter analyze` | 首次发现拆分时缺少 `AppThemeMode` 类型导入；补回主题偏好类型导入后通过，无问题。 |
| 2026-08-13 | `/develop` 迭代 3 | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 96 个变更相关 Dart 文件。 |
| 2026-08-13 | `/develop` 迭代 4 | `flutter test test\app_shell_boundaries_test.dart test\chat_background_completion_test.dart test\widget_test.dart test\ui_preview_test.dart test\feature_flag_integration_test.dart test\android_keyboard_window_config_test.dart test\tiktok_app_shell_test.dart` | 通过，共 57 项测试；覆盖依赖边界、Chat 后台生命周期、导航、功能开关、键盘窗口配置与主壳行为。 |
| 2026-08-13 | `/develop` 迭代 4 | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 | `/develop` 迭代 4 | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 99 个变更相关 Dart 文件。 |
| 2026-08-13 | `/develop` 迭代 4 | 源码结构搜索与 `test/app_shell_boundaries_test.dart` | `SparkApp` 参数面为 `key/config/showSplash/dependencies`；`SparkShell` 参数面为 `key/required dependencies/features`；应用生产源码只有 `spark_app.dart` 调用一次 `SparkDependencies.preview(...)`。 |
| 2026-08-13 | `/test` | `git branch --show-current; git status --short` | 分支为 `refactor/app-shell-boundaries`；进入门禁前工作区干净。 |
| 2026-08-13 | `/test` | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 99 个变更相关 Dart 文件。 |
| 2026-08-13 | `/test` | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 | `/test` | `flutter test` | 通过，共 532 项测试；无失败、错误或超时。 |

## 8. 审查与交付

- 审查范围：`5e4dd9c2a65a9e9230c83990a8dd7c309a5da30a..HEAD`，9 个改动文件，新增 1118 行、删除 750 行；前序累计改动沿用各自已审查台账结论。
- 规格核对：8 项验收标准全部满足；`spark_app.dart` 62 行，闪屏/会话/导航已迁出；完整依赖仅根解析一次；两个构造参数面已收口；行为与生命周期定向及全量测试均覆盖。
- 结构核对：提交前结构清单逐项检查；Widget/Controller 基础设施直连、领域层外部依赖、公共模块反向依赖、循环依赖、业务 utils、深层继承、超大页面继续加入独立流程、只能依赖完整 UI 验证等 10 条阻断条件均未触发。
- 阻断项：无。
- 缺陷：无。
- 建议：无。
- 审查结论：通过；不执行 `/finish`，不合入 `main`，当前 HEAD 作为下一批 worktree 基线。
- 兼容性：目标为纯应用层结构重构；不得改变用户可见行为、数据或 API。
- 风险：控制器初始化/销毁顺序、异步任务存活期、本地数据清理编排、路由回调遗漏、测试装配迁移。
- 回滚：本批次保持原子提交，可在该独立分支按提交回退；不触碰 `main`。
- 合并与归档：按用户明确要求，本任务不执行 `/finish`、不合入 `main`、不清理 worktree；完成 `/review` 后保留为下一批串行基线。

## 9. 提交记录

| 提交 | 类型 | 说明 |
| --- | --- | --- |
| `c1bd32a` | 重构、测试、文档 | 抽离 `SparkBootstrap` 与启动动画，新增独立 Widget/源码边界测试；定向测试、analyze 和格式门禁通过。 |
| `e33798f` | 重构、测试、文档 | 新增 `SparkApplicationSession` 集中根控制器生命周期、跨控制器同步与本地数据清理编排；16 项定向测试、analyze 和格式门禁通过。 |
| `3e8d1e1` | 重构、测试、文档 | 将 `SparkShell`、一级页面和路由迁至独立导航壳文件，以转导出维持兼容；45 项定向测试、analyze 和格式门禁通过。 |
| `31a7bb6` | 重构、测试 | 删除应用根与导航壳的仓储/服务镜像参数，将完整依赖解析收口至根节点；迁移测试装配并增加构造参数面与唯一 preview 调用的结构回归。 |

## 10. 当前状态

- 已完成：闪屏/bootstrap、应用运行期会话及导航展示壳均已迁出；`spark_app.dart` 由基线 781 行降至 72 行，只保留主题、一次依赖解析和根装配。`SparkApp` 与 `SparkShell` 的仓储/服务镜像参数及壳内 fallback 已删除，所有直接测试装配均改为完整 `SparkDependencies`，两条既有导入路径继续兼容。
- 下一步：进入 `/review`，只读审查完整累计 diff；通过后保留最终审查提交作为下一批 worktree 的串行基线。
- 下一步：基于本批最终审查提交创建新的独立 worktree，重新读取 DeepSeek 报告与全部相关台账，继续修复尚未处理的有效问题。
- 阻塞项：无。
