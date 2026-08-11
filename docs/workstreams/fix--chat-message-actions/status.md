# 任务台账

## 基本信息

- 任务：论文内嵌 AI 讨论隐藏无效的消息修改/删除入口
- 关联发布或里程碑：不关联发布
- 分支：`fix/chat-message-actions`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\fix--chat-message-actions`
- 基线提交：`f8932a5c06d95102a7c22aa6077f77af2dbf8f51`（main HEAD）
- 负责人：Fantasy（编排者）；执行：Claude
- 状态：已合并
- 最近更新：2026-08-12 02:25

## 目标

论文详情页内嵌 AI 讨论视图（`PaperAiDiscussionView`）中，消息的「修改」按钮与「更多 → 删除消息」入口当前显示但点击无任何效果（`PaperAiContent` 把可空回调包装成非空闭包，内嵌视图未传回调时按钮照常渲染、回调静默空转）。本任务让这两个无效入口在内嵌视图中彻底隐藏，全屏聊天页（`PaperAiChatScreen`，主聊天与论文全屏聊天共用）功能保持不变。

## 非目标

- 不为内嵌讨论视图接线消息删除/修改功能（编排者决策：隐藏而非接线）。
- 不改变全屏聊天页的删除/修改/多选行为。
- 不改动 `ChatConversationController` 及领域、数据层。

## 验收标准

- [x] 内嵌讨论视图：用户消息不显示「修改」按钮；AI 消息不显示「更多」按钮（删除消息入口消失）；复制、重新生成按钮保留。
- [x] 全屏聊天页：修改按钮、「更多 → 删除消息」、多选删除行为与现状一致。
- [x] 新增 Widget 测试覆盖上述两条。
- [x] `tool/verify_changed_dart_format.ps1`、`flutter analyze`、`flutter test` 全量通过。

## 写入范围

### 独占路径

- `lib/src/features/chat/presentation/widgets/paper_ai_content.dart`
- `lib/src/features/chat/presentation/widgets/paper_ai_message_view.dart`
- `test/paper_ai_discussion_view_test.dart`（新增）
- `docs/workstreams/fix--chat-message-actions/`

### 共享路径

- 无

## 依赖关系

- 上游任务：`feature/chat-keyboard-interactions`（已合并，全屏页多选删除与修改交互基线）。
- 并行任务核对：`feature/chat-markdown-parity` 只改 `core/widgets/spark_markdown*.dart`，与本任务文件无交集。

## 实施计划

1. `paper_ai_content.dart`：`onDelete`/`onEdit` 改为可空透传（不再包装空操作闭包）→ 验证：内嵌视图按钮消失。
2. `paper_ai_message_view.dart`：「更多」按钮仅在 `onDelete != null` 时渲染（菜单当前只有删除消息一项）。
3. 新增 Widget 测试：内嵌视图隐藏修改/更多按钮且保留复制/重试；全屏页两入口仍在。
4. 定向验证：格式门禁、`flutter analyze`、`flutter test`。

## 当前进度

- 已完成：实现与定向验证；编排者 Windows 发布版实测验收通过；合并前交付信息收集。
- 正在进行：等待合并。
- 下一步：合入 main 并做集成回归与归档。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-12 | 内嵌视图隐藏入口而非接线功能 | 编排者决策；内嵌视图保持轻量，全屏页已提供完整能力 | 只动 presentation 层两个共享组件与新增测试 |
| 2026-08-12 | 分支 slug 由 `fix--paper-discussion-message-actions` 缩短为 `fix--chat-message-actions` | 原 slug 下 Windows 插件构建路径达 262 字符超 MAX_PATH 260，MSBuild MSB3491 无法编译；subst 短盘符又使 flutter_assemble 退出 255 | worktree、分支与台账目录同步重命名，提交历史不变 |

## 验证记录

> `/finish` 合并后必须记录 development APK 与 Windows EXE 两个目标的发布版构建结果、产物路径、大小和 SHA-256（AGENTS.md §10，2026-08-11 起构建一律发布版，Android 签名未配置期间以 profile 代替）；任一目标失败时不得填写“已合并”或清理 worktree。

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter test test/paper_ai_discussion_view_test.dart` | 2 通过 | 2026-08-12 |
| `flutter test test/paper_ai_mobile_chat_ui_test.dart test/paper_ai_chat_keyboard_interactions_test.dart test/ui_preview_test.dart` | 40 通过，无回归 | 2026-08-12 |
| `tool/verify_changed_dart_format.ps1` | 通过（3 文件） | 2026-08-12 |
| `flutter analyze` | No issues found | 2026-08-12 |
| `flutter test`（全量） | 413 全过 | 2026-08-12 |
| Windows 桌面发布版 `flutter run --release` 实测：内嵌讨论无修改/更多按钮、复制/重试保留；全屏聊天修改/删除入口可用 | 通过（编排者验收） | 2026-08-12 |
| 长 slug worktree `flutter build windows --release` | 失败：MSB3491 路径超 MAX_PATH 260；已通过缩短 slug 根治（见决策记录） | 2026-08-12 |
| main 集成回归（合并后）：`tool/verify_changed_dart_format.ps1 -BaseRevision 85e3b23` + `flutter analyze` + `flutter test` 全量 | 全过（421 项） | 2026-08-12 |
| main 集成构建（合并后）：`flutter build apk --profile --flavor development --dart-define=SPARK_ENV=development`（Android release 签名未配置，按 AGENTS.md §10 以 profile 代替，产物类型 profile） | 通过（128.6s）；产物 `build/app/outputs/flutter-apk/app-development-profile.apk`，119,278,476 B（113.8 MB），SHA-256 `851f783a7ba483d0c26640307995ffadbca8199438d70c1c5b993bee4713e06b` | 2026-08-12 |
| main 集成构建（合并后）：`flutter build windows --release --dart-define=SPARK_ENV=development` | 通过（128.9s）；产物 `build/windows/x64/runner/Release/spark.exe`，101,888 B，SHA-256 `cdfcde6d1129aa3b01faf6ddcbc8feaab9d92b647a6b7bd00b9c712e579ba28a` | 2026-08-12 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：2026-08-12
- 阻断项：无
- 缺陷：无
- 结论：可合并（编排者 Windows 桌面发布版实测验收通过后直接批准合并，未走独立 /review 只读审查，同 `feature/chat-keyboard-interactions` 先例）

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 968c624 | 文档（台账）：创建论文讨论消息操作任务台账 | /start | 无（纯文档） |
| ab37e6b | 修复（ChatPaper）：隐藏论文内嵌讨论中无效的消息操作入口 | /develop | 格式门禁、analyze、test 全量 413 通过 |
| ffced6e | 文档（台账）：记录消息操作隐藏实现检查点 | /develop | 无（纯文档） |
| a3df644 | 文档（台账）：缩短分支 slug 绕开 Windows 路径长度上限 | /finish 前置 | 无（纯文档） |

## 交付准备（合并前收集）

### 交付摘要

论文详情页内嵌 AI 讨论视图中，原先显示但点击无效的「修改」按钮与「更多 → 删除消息」入口已彻底隐藏：AI 消息只保留「复制 / 重新生成」，用户消息只保留「复制」。全屏聊天页（主聊天与论文全屏聊天）的修改、删除与多选行为完全不变。与计划一致（编排者拍板隐藏而非接线）。

### 实际变更

- 领域与业务逻辑：无。
- 数据与基础设施：无。
- 界面与交互：`paper_ai_content.dart` 的 `onDelete`/`onEdit` 由非空闭包包装改为可空透传；`paper_ai_message_view.dart` 的「更多」按钮仅在存在删除回调时渲染（菜单当前只有删除消息一项）。
- 测试与工具：新增 `test/paper_ai_discussion_view_test.dart`（内嵌隐藏两入口且保留复制/重试、全屏页两入口可用 2 用例）。
- 文档：本任务台账。

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：无
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：低。改动仅 2 处条件渲染逻辑（共 8 行），全屏页路径由现有 40 项相关测试与新增对照用例兜底；编排者已完成 Windows 发布版实测。
- 回滚方式：revert 任务提交 `ab37e6b`，无数据影响。

### 文档更新建议

- 不适用；消息操作入口的显隐不改变 `docs/development.md` 的功能能力状态（同 `feature/chat-keyboard-interactions` 先例）。

### 未完成与后续工作

- 若后续决定为内嵌讨论视图接线删除/修改功能，底层 `ChatConversationController.deleteMessagesAt` 与 `editLatestPromptAndRetry` 已具备能力，仅需 presentation 层接线。

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：已合并
- 合入分支：`main`
- 最终集成提交：`929e3df`（`杂项（合并）：合入消息操作隐藏任务`）
- Pull Request：无
- 合并时间：2026-08-12 02:24:59 +08:00
- main 集成验证：格式门禁（基线 `85e3b23`，3 文件）、`flutter analyze`、`flutter test` 全量 421 项、development APK（profile，按 AGENTS.md §10 代替 release）与 Windows release EXE 双目标发布版构建全部通过；产物路径、大小与 SHA-256 见上方验证记录。
- 开发计划更新：不适用；消息操作入口显隐不改变 `docs/development.md` 的功能能力状态（同 `feature/chat-keyboard-interactions` 先例）。
- 最终后续项：若后续为内嵌讨论视图接线删除/修改功能，底层 controller 能力已具备，仅需 presentation 层接线。本台账转为只读归档，除勘误外不再更新。
