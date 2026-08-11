# 任务台账

## 基本信息

- 任务：论文内嵌 AI 讨论隐藏无效的消息修改/删除入口
- 关联发布或里程碑：不关联发布
- 分支：`fix/paper-discussion-message-actions`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\fix--paper-discussion-message-actions`
- 基线提交：`f8932a5c06d95102a7c22aa6077f77af2dbf8f51`（main HEAD）
- 负责人：Fantasy（编排者）；执行：Claude
- 状态：开发中
- 最近更新：2026-08-12 00:30

## 目标

论文详情页内嵌 AI 讨论视图（`PaperAiDiscussionView`）中，消息的「修改」按钮与「更多 → 删除消息」入口当前显示但点击无任何效果（`PaperAiContent` 把可空回调包装成非空闭包，内嵌视图未传回调时按钮照常渲染、回调静默空转）。本任务让这两个无效入口在内嵌视图中彻底隐藏，全屏聊天页（`PaperAiChatScreen`，主聊天与论文全屏聊天共用）功能保持不变。

## 非目标

- 不为内嵌讨论视图接线消息删除/修改功能（编排者决策：隐藏而非接线）。
- 不改变全屏聊天页的删除/修改/多选行为。
- 不改动 `ChatConversationController` 及领域、数据层。

## 验收标准

- [ ] 内嵌讨论视图：用户消息不显示「修改」按钮；AI 消息不显示「更多」按钮（删除消息入口消失）；复制、重新生成按钮保留。
- [ ] 全屏聊天页：修改按钮、「更多 → 删除消息」、多选删除行为与现状一致。
- [ ] 新增 Widget 测试覆盖上述两条。
- [ ] `tool/verify_changed_dart_format.ps1`、`flutter analyze`、`flutter test` 全量通过。

## 写入范围

### 独占路径

- `lib/src/features/chat/presentation/widgets/paper_ai_content.dart`
- `lib/src/features/chat/presentation/widgets/paper_ai_message_view.dart`
- `test/paper_ai_discussion_view_test.dart`（新增）
- `docs/workstreams/fix--paper-discussion-message-actions/`

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

- 已完成：任务边界确认（编排者拍板隐藏方案）；必读文档与并行任务核对；worktree 与分支创建；台账初始化。
- 正在进行：等待编码。
- 下一步：实施计划第 1 步。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-12 | 内嵌视图隐藏入口而非接线功能 | 编排者决策；内嵌视图保持轻量，全屏页已提供完整能力 | 只动 presentation 层两个共享组件与新增测试 |

## 验证记录

> `/finish` 合并后必须记录 development APK 与 Windows EXE 两个目标的发布版构建结果、产物路径、大小和 SHA-256（AGENTS.md §10，2026-08-11 起构建一律发布版，Android 签名未配置期间以 profile 代替）；任一目标失败时不得填写“已合并”或清理 worktree。

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：可合并 / 需修复 / 需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

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

- 已知风险：
- 回滚方式：

### 文档更新建议

### 未完成与后续工作

- 无

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：
- 合入分支：`main`
- 最终集成提交：
- Pull Request：无
- 合并时间：
- main 集成验证：
- 开发计划更新：
- 最终后续项：
