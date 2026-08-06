# 任务台账

> 单文件任务台账，由 `/start` 创建、`/develop` 与 `/test` 持续更新。`/finish` 在任务分支收集合并前交付信息；任务真实合入 `main` 后，再在 `main` 补齐最终合并归档。

## 基本信息

- 任务：AI 聊天配色接入全局主题
- 关联发布或里程碑：无；按 ChatPaper P2 缺陷修复处理
- 分支：`fix/chat-theme-colors`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\fix--chat-theme-colors`
- 基线提交：`2dd2b4dc3af81d4ca94f2daf4961c3a66eacdd95`
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：开发完成，等待 `/test`
- 最近更新：2026-08-07 01:13

## 目标

AI 聊天页面的背景、消息气泡、Composer、推理面板和交互状态色随全局主题色切换一致更新，不再残留独立固定粉色配色。

## 非目标

- 不新增深色模式或新的主题选择项。
- 不修改聊天业务逻辑、会话持久化、AI 服务契约或页面信息架构。
- 不重新设计现有聊天布局、间距、圆角、字体或交互流程。
- 不绑定发布版本，也不执行发布流程。

## 验收标准

- [x] 切换至少两种全局主题色后，AI 聊天页面背景、用户气泡、Composer、推理面板及主要激活/选择状态均使用当前主题派生色。
- [x] 聊天 presentation 不再以固定粉色 token 或原始色值控制非品牌语义色；颜色统一从当前 `ThemeData` 获取。
- [x] 第三方品牌色如确需保留，必须与主题语义色分离并有明确用途，不得复用于搜索、推理或选择状态。
- [x] 新增 Widget 回归测试，能够在修复前失败、修复后通过，并覆盖主题切换后的实际组件颜色。
- [x] 现有聊天交互、主题控制器和主题面板测试无回归。
- [ ] 格式、静态分析、全量测试和 development debug APK 构建通过。

## 写入范围

### 独占路径

- `lib/src/features/chat/presentation/`
- `test/paper_ai_composer_test.dart`
- `test/paper_ai_content_test.dart`
- `test/paper_ai_message_view_test.dart`
- `test/paper_ai_mobile_chat_ui_test.dart`
- `docs/workstreams/fix--chat-theme-colors/status.md`

### 共享路径

- `lib/src/core/theme/spark_theme.dart`：仅在现有 `ColorScheme` 无法表达聊天语义色时增加全局主题扩展，不改其他模块视觉契约。
- `test/paper_theme_test.dart`：仅补充全局主题到聊天语义色的映射测试。

## 依赖关系

- 上游任务：`feature/chat-ui-mobile`、`feature/chat-ux-polish`，均已合并。
- 外部接口或数据源：无。

## 实施计划

1. 在 `test/paper_ai_mobile_chat_ui_test.dart` 增加蓝色/绿色主题重建用例，直接检查页面、用户气泡、Composer、推理卡片与激活状态的实际渲染颜色，并确认修复前失败。
2. 将聊天语义色统一映射到当前 `ThemeData`；优先复用 `ColorScheme`，只有确有独立语义时才增加主题扩展。
3. 替换 `lib/src/features/chat/presentation/` 中页面、消息、Composer、推理、选择态和辅助内容的固定非品牌颜色，保留现有布局与交互。
4. 运行主题外颜色静态审计、聊天与主题定向测试、格式检查和 `flutter analyze`，更新台账并形成原子提交；全量门禁与 APK 构建留给 `/test`。

## 当前进度

- 已完成：新增并完成红绿主题切换 Widget 测试；将聊天页面、消息、Composer、推理、来源、选择态、会话滑动操作和模型头像的颜色接入当前 `ThemeData.colorScheme`；完成聊天与主题定向回归、格式检查、静态分析和固定颜色审计；将任务 worktree 迁移到规范要求的 `Spark-worktrees`。
- 正在进行：无；`/develop` 阶段已完成。
- 下一步：由编排者触发 `/test`，运行全量测试与 development debug APK 构建门禁。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-07 | 以本地 `main` 的 `2dd2b4d` 为基线 | `origin/main` 尚未包含 PaperFlow→Spark 重命名，本任务涉及已重命名的主题与聊天文件 | 分支包含本地 `main` 领先远端的三个提交，合并前需保持相同基线 |
| 2026-08-07 | 优先从 `ThemeData.colorScheme` 派生聊天颜色 | 避免业务 Widget 直接读取全局控制器，并保持主题可测试、可继承 | 仅语义不足时再增加 `ThemeExtension` |
| 2026-08-07 | 以蓝色/绿色主题重建同一聊天场景作为主要证据路径 | 能直接观察主题输入变化是否到达真实 Widget 颜色，避免只测试颜色帮助类 | 回归测试覆盖页面、消息、Composer、推理与激活态；静态审计负责补漏 |
| 2026-08-07 | 将任务 worktree 迁移到 `Spark-worktrees` | 根 `AGENTS.md` 在开发期间更新了合法 worktree 根路径 | 使用 Git 原生 `worktree move` 保留分支与全部未提交改动，后续流程统一使用新路径 |
| 2026-08-07 | 不增加 `ThemeExtension`，由 `ColorScheme` 直接派生聊天语义色 | 当前主题已提供完整的主色、容器色、前景色和错误色语义 | 页面底色、Composer 和推理表面分别以 2%、6%、8% 主色叠加到 surface；文字与图标使用对应 `on*` 语义色 |
| 2026-08-07 | 主题测试同步切换 `ThemeController` 后创建 `SparkTheme.light()` | 异步配置存储会让 Widget 测试受持久化时序影响，而颜色派生本身是同步状态 | 测试稳定覆盖真实主题构造与组件渲染，不依赖设备存储完成时间 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter test test/paper_theme_test.dart test/paper_ai_mobile_chat_ui_test.dart` | 基线通过 11 项；同时证明现有测试未覆盖聊天颜色随主题变化 | 2026-08-07 |
| 主题外颜色静态审计 | 基线失败，聊天 presentation 命中 47 处固定 token 或原始色值引用 | 2026-08-07 |
| 新增 `mobile chat colors follow the active Material theme` Widget 用例 | 修复前稳定失败；固定聊天底色与蓝色主题期望不一致，证明用例可捕获缺陷 | 2026-08-07 |
| `flutter test test/paper_ai_mobile_chat_ui_test.dart test/paper_ai_composer_test.dart test/paper_ai_content_test.dart test/paper_ai_message_view_test.dart test/paper_theme_test.dart test/chat_session_controller_test.dart` | 通过，共 36 项 | 2026-08-07 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision 2dd2b4dc3af81d4ca94f2daf4961c3a66eacdd95` | 通过，9 个 Dart 文件格式正确 | 2026-08-07 |
| `flutter analyze` | 通过，无 issue | 2026-08-07 |
| `rg -n "\\bColor\\(0x|\\bColors\\.(?!transparent)|SparkColors" lib/src/features/chat/presentation --pcre2` | 无命中；聊天 presentation 不再含固定原始颜色、非透明 `Colors.*` 或 `SparkColors` 引用 | 2026-08-07 |
| `git diff --check` | 通过 | 2026-08-07 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：待 `/review`
- 阻断项：待 `/review`
- 缺陷：待 `/review`
- 结论：待 `/review`

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `a0e52a8` | `fix(chat): follow global theme colors` | `/develop` | 定向测试 36 项、格式检查、`flutter analyze` 与固定颜色审计通过 |

## 交付准备（合并前收集）

### 交付摘要

待 `/finish` 根据实际实现补充。

### 实际变更

- 领域与业务逻辑：无变化。
- 数据与基础设施：无变化。
- 界面与交互：聊天专用颜色 token 改为从当前 `ColorScheme` 派生；聊天首页、详情页、Composer、消息、推理、来源、选择态、滑动操作和模型头像随全局主题更新；布局与交互流程不变。
- 测试与工具：新增蓝色/绿色真实主题 Widget 回归，直接验证页面、用户气泡、Composer、推理表面和发送按钮颜色。
- 文档：已创建本任务台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：无数据兼容影响；仅聊天 presentation 视觉颜色随主题变化。

### 已知风险与回滚

- 已知风险：当前开发验证覆盖蓝色与绿色主题，五种主题的完整人工视觉体验不在本阶段验证范围；完整全量测试与 development APK 构建待 `/test`。
- 回滚方式：使用 `git revert a0e52a8` 回滚功能提交；不涉及数据回滚。

### 文档更新建议

- 本任务修复既有 ChatPaper UI 缺陷，预计不改变 `docs/development.md` 的能力状态；合并时按实际结果确认。

### 未完成与后续工作

- `/develop` 已完成；待 `/test`、`/review` 与 `/finish` 按编排者指令依次执行。

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：待合并后填写。
- 合入分支：待合并后填写。
- 最终集成提交：待合并后填写。
- Pull Request：待合并后填写。
- 合并时间：待合并后填写。
- main 集成验证：待合并后填写。
- 开发计划更新：待合并后确认是否适用。
- 最终后续项：待合并后填写。
