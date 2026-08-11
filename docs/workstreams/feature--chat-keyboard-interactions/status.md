# 任务台账

## 基本信息

- 任务：ChatPaper 输入栏吸收开源参考实现的三项键盘交互设计
- 关联发布或里程碑：不关联发布
- 分支：`feature/chat-keyboard-interactions`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\feature--chat-keyboard-interactions`
- 基线提交：`948f3aff8a791aeb1602c1ef38313fde2278c4a6`（main HEAD）
- 负责人：Fantasy（编排者）；执行：Claude
- 状态：待审查
- 最近更新：2026-08-11 23:05

## 目标

让 ChatPaper 聊天页（主聊天与论文聊天共用的 `PaperAiChatScreen`）具备三项经开源参考验证的键盘交互：① 进入消息多选等场景时统一收起键盘；② 桌面端发送后输入框保持焦点可连续输入；③ 确认已有 IME 差值滚动实现不劣于 rikkahub 参照算法。

## 非目标

- 不实现 `enterToSend`（移动端回车键发送/换行切换）设置项，另立任务。
- 不改变 IME inset 消费、输入栏平移、消息滚动锚定的既有机制（`fix/android-keyboard-jank` 已合并）。
- 不改变发送行为、会话状态或 AI 请求契约；不调整输入区视觉。

## 验收标准

- [x] 桌面平台（Windows/macOS/Linux）发送消息后输入框保持焦点，可直接继续输入。
- [x] 移动平台（Android/iOS）发送消息后键盘收起（维持 `feature/chat-ux-polish` ⑦ 的既有行为）。
- [x] 长按消息进入多选模式时键盘统一收起，退出多选不自动弹键盘。
- [x] 新行为有对应 Widget 测试（桌面/移动平台分支 + 多选收键盘）。
- [x] `flutter analyze`、`flutter test`、`tool/verify_changed_dart_format.ps1` 通过。
- [x] 台账记录 rikkahub ime 滚动对照结论（见决策记录，既有实现为参照算法超集，未改代码）。

## 写入范围

### 独占路径

- `lib/src/features/chat/presentation/paper_ai_chat_screen.dart`
- `test/paper_ai_chat_keyboard_interactions_test.dart`（新增）
- `docs/workstreams/feature--chat-keyboard-interactions/`

### 共享路径

- 无

## 依赖关系

- 上游任务：`fix/android-keyboard-jank`（已合并，IME 差值滚动与输入栏独立平移）；`feature/chat-ux-polish`（已合并，⑦ 发送后收起键盘=移动端行为基线）。
- 参考实现（只读，不复制代码）：`references/源仓库/kelivo`（AGPL-3.0）`home_page_controller.dart` 的 dismissKeyboard 与发送后桌面保焦；`references/源仓库/rikkahub`（AGPL-3.0）`ImeLazyListAutoScroller.kt`；`references/源仓库/flutter_ai_toolkit`（BSD-3）发送后 requestFocus。

## 实施计划

1. rikkahub ime 滚动对照验证（只读分析，结论写台账；预期无需改代码）。
2. 桌面端发送后保持焦点（`_send` 平台分支）+ Widget 测试（桌面/移动两分支）。
3. `_dismissKeyboard()` 统一收键盘入口，接入多选模式入口 + Widget 测试。
4. 定向验证：格式检查、`flutter analyze`、`flutter test`。

## 当前进度

- 已完成：任务边界确认；必读文档与历史台账阅读；现状分析；rikkahub ime 滚动对照（无代码改动，结论见决策记录）；桌面端发送后保持焦点；`_dismissKeyboard()` 三层兜底并接入多选入口；3 个 Widget 测试；/test 完整验证门禁全过（diff check/格式/analyze/test 410/APK+Windows 构建）；Windows 桌面端启动实测；profile 包手机端实测（键盘弹出顺滑，debug 卡顿确认为构建类型假象）。
- 正在进行：等待编排者触发 /review。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-11 | 只做 1-3 项，enterToSend 另立任务 | 编排者拍板；设置项涉及存储与设置页入口，范围另计 | 本任务不动设置与 composer 回车行为 |
| 2026-08-11 | 改动落在共用的 `PaperAiChatScreen` | 主聊天（spark_app）与论文聊天（main_ai_chat_screen）共用同一屏，一处改动两处生效 | 不涉及其他 feature 模块 |
| 2026-08-11 | 第 3 项（ime 滚动对照）无代码改动 | 对照结论：Spark 现有实现（`fix/android-keyboard-jank`）是 rikkahub `ImeLazyListAutoScroller` 的超集——① 同样的高度差值思想（`_ImeAnchoringScrollController.updateImeInset` 算 delta 对应 rikkahub 的 scrollBy 差值）；② 超集：底部锚定阈值守卫（距底 >160px 不跟随，阅读中不被拽走，rikkahub 无此守卫）；③ 超集：修正延迟到 `correctForNewDimensions` 一次性应用，避免与布局放大打架；④ 超集：输入栏独立 `Transform.translate` 平移 + `removeViewInsets`，消息视口不参与 IME 合成变换 | 验收标准该项以台账记录为证据 |
| 2026-08-11 | `_dismissKeyboard` 保留 kelivo 的三层兜底（含 `TextInput.hide`） | Spark 主验收平台是 Android，kelivo 加此层正是防御 Android 输入法在焦点转移后的残留；成本一行，且 `Future.ignore()` 吞掉无平台通道环境（测试）的异步错误 | presentation 调用 `SystemChannels` 属框架 API 而非平台插件，不违反分层约束 |
| 2026-08-11 | 桌面保焦范围不含 Web | 验收平台为 Android 手机 + Windows 桌面；kelivo 同样只判三个桌面 OS | Web 平台维持 unfocus 现状 |
| 2026-08-11 | 后续构建一律发布版（Android 签名未配置期间以 profile 代替） | 编排者指示；本任务手机实测时 debug 包出现键盘弹出卡顿，profile 包顺滑，确认卡顿为 debug 构建（JIT/断言）假象，debug 产物会误导验收 | 已记入 AGENTS.md §10（main 75dc0aa）；本任务 /finish 起门禁产物按发布版执行 |

## 验证记录

> `/finish` 合并后必须记录 development APK 与 Windows EXE 两个目标的发布版构建结果、产物路径、大小和 SHA-256（AGENTS.md §10，2026-08-11 起构建一律发布版，Android 签名未配置期间以 profile 代替）；任一目标失败时不得填写“已合并”或清理 worktree。

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter test test/paper_ai_chat_keyboard_interactions_test.dart` | 3 通过 | 2026-08-11 |
| `tool/verify_changed_dart_format.ps1` | 通过（2 文件） | 2026-08-11 |
| `flutter analyze` | No issues found | 2026-08-11 |
| `flutter test`（全量） | 410 全过，无回归 | 2026-08-11 |
| rikkahub `ImeLazyListAutoScroller.kt` vs `paper_ai_chat_screen.dart` `_ImeAnchoringScrollController` 人工对照 | Spark 为参照算法超集，未改代码 | 2026-08-11 |
| `git diff --check HEAD~3 HEAD` | 通过 | 2026-08-11（/test 阶段复跑） |
| `tool/verify_changed_dart_format.ps1`（/test 复跑） | 通过 | 2026-08-11 |
| `flutter analyze`（/test 复跑） | No issues found | 2026-08-11 |
| `flutter test` 全量（/test 复跑） | 410 全过 | 2026-08-11 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development` | 通过（71.1s），产物 `build/app/outputs/flutter-apk/app-development-debug.apk` | 2026-08-11 |
| `flutter build windows --debug --dart-define=SPARK_ENV=development` | 通过（63.3s），产物 `build/windows/x64/runner/Debug/spark.exe` | 2026-08-11 |
| Windows 桌面端 `flutter run` 启动实测 | 应用正常启动运行，无障碍日志噪音与本次改动无关 | 2026-08-11 |
| `flutter build apk --profile --flavor development --dart-define=SPARK_ENV=development` | 通过（126.2s），产物 `build/app/outputs/flutter-apk/app-development-profile.apk`（86.4MB） | 2026-08-11 |
| 手机端实测（profile 包）：键盘弹出动画与列表跟随 | 顺滑无卡顿；debug 包卡顿确认为构建类型（JIT/断言）假象，非实现问题 | 2026-08-11 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：可合并 / 需修复 / 需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| d9ae02d | 文档（台账）：创建键盘交互任务台账 | /start | 无（纯文档） |
| 201a4bd | 新增（ChatPaper）：键盘交互对齐主流 AI 客户端 | /develop | 格式门禁、analyze、test 全量 410 通过 |

## 交付准备（合并前收集）

### 交付摘要

（合并前填写）

### 实际变更

- 领域与业务逻辑：
- 数据与基础设施：
- 界面与交互：
- 测试与工具：
- 文档：

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：无
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：（合并前填写）
- 回滚方式：revert 任务提交，无数据影响。

### 文档更新建议

- `docs/development.md` §3.2 ChatPaper 任务表视交付情况补充。

### 未完成与后续工作

- enterToSend（移动端回车发送/换行切换）设置项：另立任务。

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：（待合并后填写）
- 合入分支：`main`
- 最终集成提交：（待合并后填写）
- Pull Request：无
- 合并时间：（待合并后填写）
- main 集成验证：（待合并后填写）
- 开发计划更新：（待合并后填写）
- 最终后续项：（待合并后填写）
