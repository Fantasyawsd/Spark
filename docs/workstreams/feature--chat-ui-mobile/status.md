# 任务台账

## 基本信息

- 任务：复刻 RikkaHub 移动端 AI 聊天 UI
- 关联发布或里程碑：无
- 分支：`feature/chat-ui-mobile`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\feature--chat-ui-mobile`
- 基线提交：`e2ac254`
- 负责人：Codex
- 状态：待审查
- 最近更新：2026-08-04 23:58

## 目标

在 PaperFlow 现有 ChatPaper 业务控制器和会话持久化之上，复刻 RikkaHub 移动端聊天页的主要视觉结构与交互：顶部栏、右侧用户消息、左侧 Assistant 消息、推理卡片、消息操作栏、来源列表、建议 Chips 和底部 Composer。

## 非目标

- 不实现 RikkaHub 桌面端布局。
- 不引入 RikkaHub 的消息树、MCP、Workspace 或完整多 Provider 架构。
- 不改变 PaperFlow 现有 AI 服务、会话持久化和搜索业务契约。
- 不启动 Android 模拟器或自动执行浏览器测试。

## 验收标准

- [ ] 移动端顶部栏结构接近标注截图：会话标题、模型副标题、大纲预览按钮。
- [ ] 用户消息右对齐浅色圆角气泡，Assistant 消息显示模型头像/名称并使用自然内容流。
- [ ] Markdown 正文、消息操作图标、推理卡片、来源列表和加载/错误状态可见且层级接近截图。
- [ ] 推理卡片支持折叠/展开、计时、生成中状态和完成后自动收起。
- [ ] 底部 Composer 为悬浮圆角容器，支持多行输入、模型/搜索/推理按钮、发送/停止按钮，并正确贴合键盘。
- [ ] 现有聊天控制器行为和已有测试不回归。

## 写入范围

### 独占路径

- `lib/src/features/chat/presentation/`
- `test/paper_ai_*_test.dart`
- `docs/workstreams/feature--chat-ui-mobile/status.md`

### 共享路径

- 无

## 依赖关系

- 上游任务：无
- 外部接口或数据源：无；视觉参考来自 `C:\Users\Fantasy\Desktop\PaperFlow-worktrees\references\rikkahub\docs\img\chat.png` 及用户标注截图。

## 实施计划

1. 盘点现有 ChatPaper presentation 组件和测试，建立移动端视觉组件边界。
2. 重构页面壳、消息视图、推理卡片、操作栏和 Composer，使其接近标注截图。
3. 增加关键 Widget 测试，运行格式、analyze、test 和相关构建检查。
4. 记录验证证据、风险和后续未完成项。

## 当前进度

- 已完成：创建独立分支和 worktree；完成移动端顶部栏、对话大纲、消息布局、推理卡片、消息操作栏、来源列表、建议 Chips 和 Composer。
- 正在进行：完成提交前审查。
- 下一步：由编排者进行移动端人工验收。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-04 | 只复刻移动端 UI | 用户明确不做桌面端 | 不实现永久侧边栏和宽屏布局 |
| 2026-08-04 | 保留 PaperFlow 业务控制器 | 目标是视觉复刻，不迁移 RikkaHub 后端架构 | 仅改 presentation 层和必要的展示状态 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `dart format` + `tool/verify_changed_dart_format.ps1` | 通过，9 个 Dart 文件格式检查通过 | 2026-08-04 |
| `git diff --check` | 通过 | 2026-08-04 |
| `flutter analyze` | 通过，无 issue | 2026-08-04 |
| 定向聊天 UI / 集成测试 | 通过，47 个测试 | 2026-08-04 |
| `flutter test` | 通过，250 个测试 | 2026-08-04 |
| `flutter build apk --debug --flavor development --dart-define=PAPERFLOW_ENV=development` | 通过，生成 development debug APK | 2026-08-04 |
| `flutter run -d windows` | 未执行：项目规范要求启动前先与用户确认，且本任务仅做移动端 UI | 2026-08-04 |

## 审查结论

> 本轮完成提交前的人工 diff 审查，未发现阻断项。

- 审查日期：2026-08-04
- 阻断项：无
- 缺陷：移动端人工截图验收尚未执行；模型/Provider 文案目前通过组件默认值注入，后续接入动态配置时需同步。
- 结论：可合并，待编排者人工验收

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `d2fc79f` | `feat(chat): replicate mobile chat UI` | 移动端 UI 复刻与验证 | analyze 通过；250 个测试通过；development debug APK 构建通过 |
| `d2fc79f` | `feat(chat): replicate mobile chat UI` | 移动端 UI 复刻与验证 | analyze 通过；250 个测试通过；development debug APK 构建通过 |

## 交付记录（合并前补齐）

### 交付摘要

以用户提供的 RikkaHub 移动端截图为基准，完成 PaperFlow ChatPaper 移动端 UI 复刻，保留现有 AI 服务、流式会话和持久化控制器。

### 实际变更

- 领域与业务逻辑：无；仅使用现有 ChatConversationController 状态。
- 数据与基础设施：无。
- 界面与交互：重做移动端聊天壳、顶部栏、抽屉、消息视图、推理卡片、来源、建议和 Composer；新增对话大纲预览和思考深度 Bottom Sheet。
- 测试与工具：更新聊天 UI Widget 测试，新增移动端聊天壳测试。
- 文档：本台账

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：无
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：未在真实 Android 设备上做截图级人工对照；模型名称目前由 `PaperAiChatScreen` 默认参数提供。
- 回滚方式：revert 本分支提交，不涉及数据迁移

### 文档更新建议

- 本次只涉及移动端 ChatPaper presentation，不需要同步开发计划。

### 未完成与后续工作

- 由编排者启动 Android 移动端人工验收；根据截图对照继续微调尺寸、颜色和图标。
