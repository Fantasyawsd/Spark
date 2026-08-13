# ChatPaper 会话设置边界任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

从 `ChatConversationController` 提取会话设置的当前值、修订号、加载竞态、保存和诊断职责，使主 Controller 聚焦消息请求状态机，同时保持公开 API 和行为不变。

## 非目标

- 不改变 system prompt 组装、设置字段或持久化 schema。
- 不调整消息请求、流式消费或会话消息写队列。
- 不修改设置界面和用户可见文案。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/chat-conversation-settings-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-41`
- 基线：`efc4286`

## 验收标准

- [x] 设置值、修订号和持久化逻辑独立于主 Controller 文件。
- [x] 迟到加载不能覆盖用户更新，保存和加载失败诊断保持不变。
- [x] `ChatConversationController` 的公开设置 API 和 prompt 行为保持不变。
- [x] 定向测试、完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `lib/src/features/chat/application/chat_conversation_settings_state.dart`
- `lib/src/features/chat/application/chat_conversation_controller.dart`
- `test/chat_conversation_settings_state_test.dart`
- `docs/workstreams/refactor--chat-conversation-settings-boundary/status.md`

## 实施计划

1. 提取设置状态、加载竞态和保存诊断组件。
2. 将主 Controller 的设置 API 委托给新组件。
3. 新增独立组件测试并运行现有会话设置回归。
4. 完成完整门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-14 |
| `flutter test test/chat_conversation_settings_state_test.dart test/chat_conversation_controller_test.dart test/chat_session_settings_test.dart` | 通过，共 24 项 | 2026-08-14 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision efc4286` | 通过，检查 3 个 Dart 文件 | 2026-08-14 |
| `flutter analyze` | 通过，无问题 | 2026-08-14 |
| `flutter test` | 通过，共 575 项 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |

## 审查结论

只读审查通过：阻断项 0、缺陷 0、建议 0。设置状态、加载修订号、保存诊断和迟到加载保护均已独立；主 Controller 仍负责消息请求和 prompt 组装，公开设置 API 保持兼容。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `220504a` | `重构（ChatPaper）：拆分会话设置状态` | `/develop`、`/test`、`/review` | 定向测试 24 项、格式检查、静态分析和全量测试 575 项均通过；只读审查无发现 |
