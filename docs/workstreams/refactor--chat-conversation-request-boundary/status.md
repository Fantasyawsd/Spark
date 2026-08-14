# ChatPaper 请求生命周期边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

从 `ChatConversationController` 提取 AI 请求状态、服务选择、流式响应聚合、取消令牌、搜索状态和通知节流，使 Controller 聚焦会话命令、初始化、消息编辑与持久化编排。

## 非目标

- 不改变消息顺序、重试、取消、搜索或推理强度行为。
- 不改变会话和设置持久化契约。
- 不改变 `ChatConversationController` 的公开 API 或现有导入路径。
- 不进一步拆分已经聚焦频道选择与投影的 `PaperFeedController`。
- 不进行客户端人工验收，不构建 APK/EXE，不合入 `main`。

## 分支与基线

- 分支：`refactor/chat-conversation-request-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-46`
- 基线：`a42d8a3`

## 验收标准

- [x] Controller 不再内嵌 AI 服务适配、流聚合和请求取消实现。
- [x] `ChatRequestStatus` 仍可从原 Controller 文件导入。
- [x] 同步、流式、请求级取消、搜索状态、重试和错误行为保持不变。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `lib/src/features/chat/application/chat_conversation_controller.dart`
- `lib/src/features/chat/application/chat_conversation_request_state.dart`
- `test/chat_conversation_request_state_test.dart`
- `docs/workstreams/refactor--chat-conversation-request-boundary/status.md`

## 实施计划

1. 提取请求生命周期状态和服务交互。
2. 让 Controller 通过请求状态对象转发公开状态与命令。
3. 补充请求状态独立测试并运行现有聊天回归。
4. 完成完整门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter test test/chat_conversation_request_state_test.dart test/chat_conversation_controller_test.dart test/paper_ai_conversation_controller_test.dart test/chat_background_completion_test.dart` | 通过，共 41 项 | 2026-08-14 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision a42d8a3`（首次） | 未通过，发现 2 个生产文件未格式化；使用项目 Dart 格式器修复 | 2026-08-14 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision a42d8a3`（最终） | 通过，检查 3 个 Dart 文件 | 2026-08-14 |
| `flutter analyze` | 通过，无问题 | 2026-08-14 |
| `flutter test` | 通过，共 582 项 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |

## 审查结论

只读审查通过：阻断项 0、缺陷 0、建议 0。请求状态对象完整拥有同步/流式服务选择、推理强度、搜索状态、请求级取消、消息流聚合、请求版本和 32ms 通知节流；Controller 不再持有 AI service 引用。`ChatRequestStatus` 由原 Controller 文件转导出，现有仅导入该文件的测试和展示代码继续编译。Controller 从约 489 行降至 263 行，请求状态为 266 行并有 5 项独立测试。

同时复核 `PaperFeedController`：其目录异步操作、偏好持久化和纯投影已分别位于 `PaperFeedCatalogOperations`、`PaperFeedPreferenceCoordinator` 和 `PaperFeedProjector`；剩余状态共同服务频道选择、当前位置和目录缓存这一状态机。继续拆分会制造跨对象双向同步，因此本批确认原报告中的剩余 Feed 粒度问题已不再成立，不继续修改。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `c4f03de` | `重构（ChatPaper）：拆分请求生命周期状态` | `/develop`、`/test`、`/review` | 聊天定向测试 41 项、格式检查、静态分析和全量测试 582 项均通过；只读审查无发现 |
