# 任务台账

## 基本信息

- 任务：ChatPaper 离开聊天界面后继续完成 AI 回复
- 关联发布或里程碑：无；当前 ChatPaper 体验完善任务
- 分支：`feature/chat-background-completion`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线提交：`fc6394d72cfb0d28bec85e8c7e0c2b6c79095c0a`
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：已合并
- 最近更新：2026-08-13 01:48

## 目标

当 Spark 应用进程仍存活时，用户离开主聊天、论文全屏聊天或论文内嵌讨论界面后，尚未完成的 AI 回复继续生成并持久化；用户再次进入同一会话时，直接看到生成中的最新内容或已经完成的回复。

## 非目标

- 不保证应用被强制退出、进程被系统杀死或操作系统挂起网络任务后仍能续跑；这需要服务端任务队列与恢复协议。
- 不把论文侧边临时聊天纳入持久会话；继续遵守其“随面板销毁”的既有产品边界。
- 不改变 DeepSeek 请求协议、模型选择、提示词、会话消息 schema 或现有显式“停止生成”语义。
- 不新增通知、后台下载服务、账号同步或跨设备恢复。

## 验收标准

- [x] 主聊天发送请求后立即返回会话列表，流式请求不会因页面 `dispose` 被取消；完成后重新进入可见完整回复。
- [x] 论文全屏聊天与论文详情内嵌讨论共用同一论文会话任务；从任一入口离开并从另一入口返回，不重复请求、不丢消息。
- [x] 回复尚未完成时重新进入同一会话，可见当前流式内容与“停止生成”状态，并可继续显式停止。
- [x] 用户离开期间发生请求失败，返回后可见失败状态且可以重试；不会永久锁定为发送中。
- [x] 删除单个会话或清除 ChatPaper 数据时，会先终止并移除对应后台任务，迟到写入不会把已删除数据重新写回。
- [x] Spark 根组件销毁时统一取消仍在运行的请求并释放控制器；正常页面离开只解绑界面监听，不终止请求。
- [x] 新行为有确定性测试覆盖；格式检查、`flutter analyze`、定向测试和全量 `flutter test` 通过。
- [x] Windows development App 人工验收“发送 → 离开 → 等待 → 返回”通过；启动前由编排者明确确认。

## 写入范围

### 独占路径

- `lib/src/features/chat/application/`（新增应用级会话任务所有者，并按需调整会话控制器）
- `lib/src/features/chat/presentation/paper_ai_chat_screen.dart`
- `lib/src/features/chat/presentation/main_ai_chat_screen.dart`
- `lib/src/features/chat/presentation/paper_ai_discussion_view.dart`
- `test/chat_background_completion_test.dart`（新增）
- `test/chat_conversation_controller_test.dart`
- `docs/workstreams/feature--chat-background-completion/status.md`

### 共享路径

- `lib/src/app/spark_app.dart`：组合根接线应用级会话任务所有者，并处理应用销毁与本地数据清理。
- `test/ui_preview_test.dart`：仅在现有 App 导航测试基座无法由新增聚焦测试替代时补充。
- `docs/development.md`：合并后按真实能力更新 ChatPaper 当前状态与边界。

## 依赖关系

- 上游任务：`feature/chat-ui-mobile`、`feature/chat-ux-polish`、`fix/chat-message-actions` 均已合并；本任务保持其 UI、会话设置和消息操作语义。
- 外部接口或数据源：现有 DeepSeek Chat/SSE 服务；不新增外部依赖。
- 并行写入：启动时仅存在控制工作树，无其他任务 worktree。

## 实施计划

1. 先补失败测试，复现页面销毁会调用 `ChatConversationController.dispose()` 并取消请求的现状。
2. 在 ChatPaper application 层引入按会话 id 管理的应用级会话任务所有者；由 Spark 组合根创建和最终销毁，界面只订阅/解绑，不拥有请求生命周期。
3. 将主聊天、论文全屏聊天和论文内嵌讨论接入同一会话实例；同 id 更新上下文但不重复初始化或重复发送。
4. 串联单会话删除、全部聊天数据清理和根组件销毁，确保取消、等待写队列与移除顺序不会产生数据复活。
5. 用可控延迟流验证“发送 → 离开 → 完成 → 返回”，并覆盖生成中返回、失败、显式停止、同论文双入口和清除竞态。
6. 运行定向测试、格式门禁、`flutter analyze` 与全量 `flutter test`；经确认后启动 Windows development App 人工验收。

## 当前进度

- 已完成：读取项目必读文档与重叠 ChatPaper 台账；确认当前根因是聊天页面拥有并在离开时销毁会话控制器。
- 已完成：建立验证路径，直接观察请求未取消、最终仓储内容、返回后的界面状态及删除后的无迟到写入。
- 已完成：新增应用级 `ChatConversationCoordinator`，主聊天、论文全屏聊天和论文内嵌讨论按 contextId 复用同一控制器；页面销毁只解绑监听。
- 已完成：单会话删除、ChatPaper 全量清理和 Spark 根组件销毁均会取消相应活跃任务并排空既有写队列，避免会话复活。
- 已完成：7 项新行为测试、68 项相关回归、格式门禁、静态分析与全量 447 项测试全部通过；开发阶段双轴自审无阻断项。
- 已完成：Windows development 配置的 release App 人工验收通过；编排者明确批准进入 `/finish`。
- 已完成：任务提交已通过合并提交 `d734d2f` 进入 `main`；合并后格式、静态分析、全量测试和双目标构建均通过。
- 正在进行：无；本台账完成归档后转为只读。
- 下一步：无；强制退出或系统杀进程后的续跑属于未来服务端异步任务方向。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 生成任务归 application/组合根所有，页面只观察 | 当前页面 `dispose()` 会连带取消请求，无法跨导航存活 | 需要应用级按会话 id 注册表，控制器只在根组件销毁或业务明确取消时释放 |
| 2026-08-13 | 本轮“后台”定义为应用进程存活时离开聊天界面 | 本地 Flutter 客户端无法可靠保证进程被杀后继续执行网络请求 | 页面切换、返回上级和同会话重入纳入验收；进程级恢复留给未来服务端任务 |
| 2026-08-13 | 全屏论文聊天与内嵌讨论共享同一会话实例 | 两个入口的会话 id 相同，分别持有控制器会造成重复请求与仓储竞态 | 同一论文任意入口都能观察同一个进行中任务 |
| 2026-08-13 | 删除与清理必须先处理活跃任务 | 后台请求完成后的迟到保存可能复活已删除会话 | 将取消/移除/写队列排空纳入应用层契约和回归测试 |

## 验证记录

> `/finish` 合并后必须记录 development APK 与 Windows release EXE 两个目标的构建结果、产物路径、大小和 SHA-256；任一目标失败时不得填写“已合并”或清理 worktree。

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `git status --short`、`git diff --stat`、`git diff --cached --stat` | 基线控制工作树干净 | 2026-08-13 |
| `git worktree list --porcelain` | 启动前仅控制工作树；无并行任务冲突 | 2026-08-13 |
| `flutter test test/chat_background_completion_test.dart` | 7 项通过：根销毁取消、主聊天/论文聊天后台完成、双入口重入、单会话删除、全量清理、离开期间失败重试 | 2026-08-13 |
| ChatPaper 定向回归（6 个测试文件） | 68 项通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 8 个 Dart 文件格式检查通过 | 2026-08-13 |
| `flutter analyze` | 通过，No issues found | 2026-08-13 |
| `flutter test` | 全量 447 项通过 | 2026-08-13 |
| 开发阶段 Spec / Standards 双轴自审 | 无功能或架构阻断项 | 2026-08-13 |
| `flutter pub get` + `flutter run -d windows --release --dart-define=SPARK_ENV=development` | 当前任务分支 Windows App 启动成功；编排者人工验证“回复中离开 → 等待 → 返回同一会话”通过 | 2026-08-13 |
| main：`.\tool\verify_changed_dart_format.ps1 -BaseRevision fc6394d` | 8 个 Dart 文件格式检查通过 | 2026-08-13 |
| main：`flutter analyze` | 通过，No issues found | 2026-08-13 |
| main：`flutter test` | 全量 447 项通过 | 2026-08-13 |
| main：`flutter build apk --profile --flavor development --dart-define=SPARK_ENV=development` | Android release 签名未配置，按规范生成 profile APK；`build/app/outputs/flutter-apk/app-development-profile.apk`，119,409,548 B（113.88 MiB），SHA-256 `B1A8386AD904EAD434584F2374E4E9F54A4D60F06AE094C66960C2FD9D25270F` | 2026-08-13 |
| main：`flutter build windows --release --dart-define=SPARK_ENV=development` | 通过；`build/windows/x64/runner/Release/spark.exe`，101,888 B（99.5 KiB），SHA-256 `CDFCDE6D1129AA3B01FAF6DDCBC8FEAAB9D92B647A6B7BD00B9C712E579BA28A` | 2026-08-13 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：2026-08-13
- 阻断项：无
- 缺陷：无
- 结论：开发阶段 Spec / Standards 双轴自审通过；编排者人工验收通过并明确批准 `/finish`，同意不再单独重复 `/review`。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `c857df3` | `文档（台账）：创建聊天后台续答任务台账` | `/start` | 台账与独立 worktree 初始化 |
| `a41410d` | `新增（ChatPaper）：离开聊天后继续完成回复` | `/develop` | 7 项新行为、68 项相关回归、格式、analyze 与全量 447 项测试通过 |
| `e12a2d4` | `文档（台账）：准备聊天后台续答任务合并` | `/finish` 合并前 | 人工验收通过，交付信息完整 |
| `d734d2f` | `杂项（合并）：合入聊天后台续答功能` | `/finish` 合并 | 任务提交进入 `main` |

## 交付准备（合并前收集）

### 交付摘要

ChatPaper 的 AI 生成任务已从页面生命周期提升到 Spark 应用生命周期：用户在主聊天、论文全屏聊天或论文内嵌讨论中发起回复后，即使返回离开当前聊天界面，回复仍会继续生成并保存；再次进入同一会话时可直接看到生成中状态或完整结果。人工验收结果与计划一致。

### 实际变更

- 领域与业务逻辑：新增应用层 `ChatConversationCoordinator`，按会话 id 复用并统一销毁 `ChatConversationController`；控制器增加待写入排空能力；会话删除增加删除前任务清理接缝。
- 数据与基础设施：未改变 AI 服务、消息仓储或本地 schema；删除单会话和清除全部聊天数据前会取消活跃任务并排空已排队写入，防止迟到回复复活数据。
- 界面与交互：主聊天、论文全屏聊天和论文内嵌讨论可绑定应用级控制器；页面销毁只解绑监听，自建控制器的独立预览和测试调用仍保持原有所有权语义。
- 测试与工具：新增 7 项确定性行为测试，覆盖主/论文后台完成、双入口生成中重入、失败重试、显式根销毁取消、单会话删除和全量清理竞态；全量 447 项通过。
- 文档：更新本任务台账；合并后更新开发计划中的 ChatPaper 当前能力与进程退出边界。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：新增应用层会话任务所有者与可选 presentation 控制器注入；不改变外部 AI 服务协议。
- 旧版本兼容性：消息持久化格式不变；未注入应用级控制器的页面继续自建并自行释放控制器。

### 已知风险与回滚

- 已知风险：应用进入操作系统后台后是否持续调度取决于平台；本轮只承诺进程存活且平台未挂起时的跨界面生成。应用级协调器会在当前进程内保留已打开会话，删除、全量清理或根组件销毁时释放。
- 回滚方式：revert `a41410d`（功能、测试与契约）及后续台账提交；无数据迁移或 schema 回滚。

### 文档更新建议

- 合并后更新 `docs/development.md` 的 ChatPaper 当前状态，明确应用存活时跨页面继续生成以及进程退出边界。

### 未完成与后续工作

- 如未来需要强制退出后继续生成，需设计服务端异步任务、任务 id、结果轮询/推送和断点恢复协议。

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：已合并
- 合入分支：`main`
- 最终集成提交：`d734d2f`（`杂项（合并）：合入聊天后台续答功能`）
- Pull Request：无
- 合并时间：2026-08-13 01:41:18 +08:00
- main 集成验证：`git merge-base --is-ancestor e12a2d4 main` 通过；格式门禁、`flutter analyze`、全量 447 项测试、development profile APK 和 Windows release EXE 双目标构建全部通过，产物证据见验证记录。
- 开发计划更新：已更新 `docs/development.md` §2.1、§2.2、§3.2 和 ChatPaper 验收标准，记录跨界面续答能力及进程退出边界。
- 最终后续项：如需应用被强制退出或系统杀进程后仍继续生成，后续设计服务端异步任务、任务 id、结果轮询/推送和断点恢复协议。
