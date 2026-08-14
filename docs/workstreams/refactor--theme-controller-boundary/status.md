# 主题控制器边界重构任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 1. 任务信息

| 项目 | 内容 |
| --- | --- |
| 目标 | 消除生产代码对全局 `ThemeController.instance` 的依赖，让主题状态由组合根创建、配置、监听并显式传入主题构建与 Profile 展示边界。 |
| 非目标 | 不改变主题色、明暗模式、持久化字段、主题视觉和用户交互；不修改其他报告问题；不合入 `main`，不进行人工桌面验收。 |
| 验收标准 | 见下文“验收标准”。 |
| 分支 | `refactor/theme-controller-boundary` |
| worktree | `C:\Users\Fantasy\Desktop\Spark-worktrees\agent-8` |
| 基线 | `42b651dcf369f20f7de5a0d838911db55ad2b492`（上一批 `refactor/app-shell-boundaries` 最终审查提交） |
| 负责人 | Fantasy（编排）；Codex（执行） |
| 当前阶段 | `/review` 已完成；下一步基于最终审查提交创建新的串行 worktree |

## 2. 问题与边界

DeepSeek 报告指出 `ThemeController.instance` 是全应用全局可变单例，`SparkApp`、主题工厂、Profile 设置和本地数据清理均通过隐式全局状态协作；`debugResetForTesting()` 进一步说明测试必须手工清理单例污染。本批把主题控制器改为普通实例，由 `SparkDependencies` 作为应用级依赖持有，生产壳显式配置和监听，Profile 通过回调和控制器参数使用。

保持不变：

- `SparkThemeColor`、`AppThemeMode` 枚举与偏好仓储接口和 JSON `color`/`mode` 字段不变。
- `SparkTheme.light/dark` 的视觉输出、`SparkColors.of` 的主题扩展优先级、Profile 主题 sheet 交互不变。
- 本地数据清理仍先 flush 主题写队列，再按原顺序 reload 主题状态。

## 3. 验收标准

1. 生产源码不再引用 `ThemeController.instance`，也不再提供 `debugResetForTesting()` 单例清理入口。
2. `SparkDependencies` 持有必需的 `ThemeController`；生产与 preview 工厂各创建一次独立实例。
3. `SparkApp` 只监听注入的主题控制器，并把当前颜色显式传给 `SparkTheme.light/dark`；主题配置与 reload 生命周期保持原行为。
4. Profile 主题入口和 sheet 只使用必需的显式注入控制器，不从全局状态读取；缺失主题依赖时在编译期拒绝不完整页面装配。
5. 主题控制器的颜色、模式、持久化写队列和异常状态行为由独立实例测试覆盖；现有主题、Profile、Chat 颜色和全量应用测试保持通过。
6. 不修改主题持久化 schema、领域契约、视觉常量或其他 DeepSeek 报告问题。
7. `/test` 阶段格式检查、`flutter analyze`、`flutter test` 全部通过；按用户指示不进行人工验收，也不合入 `main`。

## 4. 写入范围

### 独占路径

- `lib/src/core/theme/theme_controller.dart`
- `lib/src/core/theme/spark_theme.dart`
- `lib/src/app/spark_dependencies.dart`
- `lib/src/app/spark_app.dart`
- `lib/src/app/spark_application_session.dart`
- `lib/src/app/spark_shell.dart`
- `lib/src/features/profile/presentation/profile_screen.dart`
- `lib/src/features/profile/presentation/profile_header.dart`
- `lib/src/features/profile/presentation/profile_settings_section.dart`
- `lib/src/features/profile/presentation/profile_theme_sheet.dart`
- 主题、Profile 和应用壳相关测试
- 本台账

### 共享路径

- 无；本批串行基于上一批最终审查提交创建。

## 5. 实施计划

1. 将 `ThemeController` 改为可实例化对象，扩展 `SparkDependencies` 并迁移应用会话生命周期。
2. 将主题工厂和 Profile 主题入口改为显式颜色/控制器参数，迁移应用壳与独立测试装配。
3. 增加结构回归测试，确认生产源码不含单例调用；运行定向测试、analyze 和格式检查。
4. 进入 `/test` 全量门禁，再进入 `/review` 只读审查并保留最终串行基线。

## 6. 当前进度

- 已完成：已读取报告、主题实现、应用壳台账和架构规范；确认本批只处理全局主题控制器。
- 已完成：`ThemeController` 已改为普通实例并由 `SparkDependencies` 持有；`SparkApp`、应用会话、本地数据清理、Profile 主题入口与主题工厂均改为显式依赖；生产源码不再引用单例。
- 已完成：主题和 Profile 测试改为每用例独立控制器，并增加实例隔离、依赖覆盖、根节点实时换色/明暗模式和源码边界回归。
- 已完成：`/test` 完整门禁与 `/review` 只读审查均通过。
- 正在进行：形成最终审查提交。
- 下一步：基于最终审查提交创建新 worktree，继续处理报告中的剩余有效问题。
- 阻塞项：无。

## 7. 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 保留 `SparkTheme.light/dark` 的默认粉色参数用于独立主题测试，但生产 `SparkApp` 始终显式传入控制器颜色。 | 避免独立 Widget/Markdown 测试被迫构造应用依赖，同时彻底移除生产全局状态读取。 | API 增加显式可选颜色，不改变默认视觉。 |
| 2026-08-13 | `ProfileScreen` 必须显式接收主题控制器，不允许缺失时静默隐藏主题入口。 | Profile 的主题能力属于完整页面契约；必需依赖能在编译期阻止不完整装配。 | 生产行为不变，独立测试各自创建隔离控制器。 |

## 8. 验证记录

| 时间 | 阶段 | 命令或检查 | 结果 |
| --- | --- | --- | --- |
| 2026-08-13 | `/develop` | `flutter test test\app_shell_boundaries_test.dart test\theme_controller_test.dart test\spark_dependencies_test.dart test\spark_theme_test.dart test\paper_ai_mobile_chat_ui_test.dart test\chat_background_completion_test.dart test\widget_test.dart test\ui_preview_test.dart test\feature_flag_integration_test.dart test\tiktok_app_shell_test.dart test\profile_catalog_status_test.dart test\profile_screen_navigation_test.dart test\deepseek_settings_widget_test.dart test\local_data_sheet_test.dart` | 通过，共 94 项；新增根主题测试首次在 `AnimatedTheme` 过渡开始时读取旧色，改为等待动画完成后通过。 |
| 2026-08-13 | `/develop` | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 | `/develop` | `.\tool\verify_changed_dart_format.ps1` | 首次列出 6 个本批生产文件需按 Dart 3.12 格式化；统一格式化后通过，共检查 110 个变更相关 Dart 文件。 |
| 2026-08-13 | `/develop` | `rg -n "ThemeController\.instance|debugResetForTesting" lib test` 与结构测试 | `lib/` 无单例引用；测试仅保留待匹配的结构守卫字符串；`debugResetForTesting` 已删除。 |
| 2026-08-13 | `/test` | `git branch --show-current; git status --short` | 分支为 `refactor/theme-controller-boundary`；进入门禁前工作区干净。 |
| 2026-08-13 | `/test` | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 110 个变更相关 Dart 文件。 |
| 2026-08-13 | `/test` | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 | `/test` | `flutter test` | 通过，共 536 项测试；无失败、错误或超时。 |

## 9. 审查与交付

- 审查范围：`42b651dcf369f20f7de5a0d838911db55ad2b492..HEAD`，21 个改动文件，新增 280 行、删除 83 行；其中代码与测试 20 个文件，另有本任务台账。
- 规格核对：7 项验收标准全部满足；生产源码无 `ThemeController.instance`，依赖容器创建或接收独立实例，应用根、主题工厂、Profile 和本地清理均显式使用同一注入对象。
- 结构核对：逐项检查提交前结构清单和 10 条阻断条件；未触发 Widget/Controller 基础设施直连、领域层外部依赖、公共模块反向依赖、循环依赖、多职数据类型、业务 utils、深层继承、超大页面新增流程或只能依赖完整 UI 验证等问题。
- 阻断项：无。
- 缺陷：无。
- 建议：无。
- 审查结论：通过；不执行 `/finish`，不合入 `main`，最终审查提交作为下一批 worktree 基线。
- 兼容性：主题偏好 JSON schema 和公开枚举保持不变；仅移除内部全局单例访问。
- 风险：遗漏主题调用点、独立测试未注入控制器、异步写队列跨实例污染。
- 回滚：按原子提交回滚，不触碰 `main`。
- 合并与归档：按用户要求不执行 `/finish`、不合入 `main`、不清理 worktree；最终审查提交作为下一批基线。

## 10. 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `9589ebf` | `重构（主题）：移除全局控制器单例` | `/develop` | 94 项定向测试、analyze、110 文件格式门禁通过；生产源码无主题单例引用。 |
