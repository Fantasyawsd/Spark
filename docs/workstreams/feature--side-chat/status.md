# 任务台账

> 单文件任务台账，由 `/start` 创建、`/develop` 与 `/test` 持续更新。`/finish` 在任务分支收集合并前交付信息；任务真实合入 `main` 后，再在 `main` 补齐最终合并归档。所有占位内容替换为真实信息。

## 基本信息

- 任务：主聊天侧边追问（side chat）
- 关联发布或里程碑：无（日常迭代，直接合 main）
- 分支：`feature/side-chat`
- Worktree：`../agent-2`
- 基线提交：`b95c259`
- 负责人：Fantasy
- 状态：开发中
- 最近更新：`2026-08-21`

## 目标

在主聊天中提供 side chat（临时追问）能力：用户探索主线问题时可随时 fork 临时会话追问概念，不污染主聊天上下文；退出即丢弃临时会话，符合 `docs/development.md §3.2 #3` 与 `§4.3` 规格。

## 非目标

- 论文聊天不接入 side chat
- 不引入服务端持久化或跨设备同步
- 不改变现有论文派生缓存、六问 AI 解读等暂缓能力
- 不改动社区/私信等非生产导航模块

## 验收标准

- [ ] 主聊天右上角虚线气泡图标可进入/退出 side chat 模式
- [ ] side chat 使用差异化主题，标题追加「（临时聊天）」，副标题提示临时会话
- [ ] 每次进入都从主聊天当时最新状态重新 fork（systemPrompt + 消息历史快照只读背景注入）
- [ ] side chat 消息不写入 `chat_sessions.json`，不进入会话列表，不污染主聊天
- [ ] 退出 side chat 时临时会话即丢弃，无残留；返回前后主聊天消息与上下文完全一致
- [ ] 切回主聊天时提示「临时聊天内容不会保存」，可勾选「不再显示」；该偏好可持久化，临时会话本身仍不保存
- [ ] `flutter analyze` 无问题，`flutter test` 全过
- [ ] 上下文边界符合 `docs/development.md §4.3` 四类分离规则

## 写入范围

### 独占路径

- `lib/src/features/chat/domain/side_chat_fork.dart`
- `lib/src/features/chat/data/side_chat_dismiss_preference_store.dart`

### 共享路径

- `lib/src/features/chat/presentation/main_ai_chat_screen.dart`（主聊天入口，负责人：本任务）
- `lib/src/features/chat/presentation/paper_ai_chat_screen.dart`（通用聊天屏，新增 side chat 模式参数）
- `lib/src/features/chat/presentation/paper_ai_ui_tokens.dart`（新增 side chat canvas）
- `lib/src/features/chat/presentation/widgets/paper_ai_chat_app_bar.dart`（新增 side chat toggle）
- 测试文件按需新增/调整（本任务负责）

## 依赖关系

- 上游任务：无（依赖现有主聊天 `ChatConversationController` / `PaperAiChatScreen` / `MainAiChatDefinition`）
- 外部接口或数据源：无（纯客户端内存会话 + DeepSeek BYOK 复用主聊天 service）

## 实施计划

1. 领域层：`SideChatFork` 纯函数（快照主聊天 context + messages → 临时 ChatContext 背景注入）→ 验证：单元测试
2. 数据层：`SideChatDismissPreferenceStore`（LocalJsonStore 持久化“不再显示”偏好）→ 验证：单元测试
3. 展示层：`MainAiChatScreen` 改为 Stateful 支持 side chat 模式切换（fork/丢弃/返回提示）→ 验证：widget 测试
4. 展示层：`PaperAiChatScreen` / `PaperAiChatAppBar` / `PaperAiUiTokens` 差异化主题与入口 → 验证：widget 测试 + analyze
5. 定向验证与收尾：`flutter analyze` + `flutter test` + 格式检查

## 当前进度

- 已完成：领域层与展示层核心实现已在分支内就绪（6 文件：2 新增 + 4 修改），`flutter analyze` 已无问题
- 正在进行：台账初始化与剩余测试补齐
- 下一步：补齐 side chat 单元/widget 测试，跑完整验证门禁，原子提交
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-21 | side chat id 固定为 `spark-main-ai-chat__side`，每次进入重新 fork | 规格要求“每次进入都从当时最新状态重新 fork，上一段已丢弃”；固定临时 id 避免持久化键污染 | 退出即 dispose，无残留 |
| 2026-08-21 | 消息历史以背景段落注入 systemPrompt，不作为聊天消息 | 满足“只读进入模式时的上下文与消息快照，追问不写入主聊天” | 主聊天 messages 不变 |
| 2026-08-21 | 偏好用独立 `side_chat_preferences.json`，不混入 `chat_sessions.json` | 偏好仅 1 bool，与会话数据分离；符合 §4.3 “偏好可持久化，临时会话本身仍不保存” | 清理聊天不误删偏好 |
| 2026-08-21 | 初始误在 main 直接改动，已 via stash 完整迁移至 feature/side-chat | 遵循 AGENTS.md 分支与 worktree 规范 | main 保持干净 b95c259 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter analyze` | No issues found | 2026-08-21 |

## 审查结论

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：可合并 / 需修复 / 需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

说明用户可以观察到的结果，以及与原计划是否一致。

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

- 已知风险：无
- 回滚方式：说明需要 revert 的提交及数据影响。

### 文档更新建议

- 需要编排者更新的开发计划；若关联发布，再列出发布资料更新建议。

### 未完成与后续工作

- 无；如有，写明后续方向和依赖。

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：已合并
- 合入分支：`main`
- 最终集成提交：`<merge-sha-or-fast-forward-tip>`
- Pull Request：无 / `<url-or-number>`
- 合并时间：`YYYY-MM-DD HH:mm`
- main 集成验证：`<commands-and-results>`
- 开发计划更新：`<updated-sections-or-not-applicable-with-reason>`
- 最终后续项：无 / `<remaining-work>`
