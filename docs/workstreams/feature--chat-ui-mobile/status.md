# 任务台账

## 基本信息

- 任务：复刻 RikkaHub 移动端 AI 聊天 UI
- 关联发布或里程碑：无
- 分支：`feature/chat-ui-mobile`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\feature--chat-ui-mobile`
- 基线提交：`e2ac254`
- 负责人：Codex
- 状态：待审查
- 最近更新：2026-08-04 23:59

## 目标

在 PaperFlow 现有 ChatPaper 业务控制器和会话持久化之上，复刻 RikkaHub 移动端聊天页的主要视觉结构与交互：顶部栏、右侧用户消息、左侧 Assistant 消息、推理卡片、消息操作栏、来源列表和底部 Composer。

## 非目标

- 不实现 RikkaHub 桌面端布局。
- 不引入 RikkaHub 的消息树、MCP、Workspace 或完整多 Provider 架构。
- 不改变 PaperFlow 现有 AI 服务、会话持久化和搜索业务契约。
- 不启动 Android 模拟器或自动执行浏览器测试。

## 验收标准

- [ ] 移动端顶部栏结构接近标注截图：可编辑会话标题、主会话/论文名副标题、大纲预览按钮。
- [ ] 用户消息只显示右对齐浅色圆角气泡；Assistant 消息显示可联网加载的模型头像/名称并使用自然内容流。
- [ ] Markdown 正文、消息操作图标、推理卡片、来源列表和加载/错误状态可见且层级接近截图。
- [ ] 推理卡片支持折叠/展开、计时、生成中状态和完成后自动收起。
- [ ] 底部 Composer 为自适应高度的悬浮圆角容器，支持多行输入、模型/搜索/推理按钮、发送/停止按钮，并正确贴合键盘。
- [ ] 现有聊天控制器行为和已有测试不回归。

## 写入范围

### 独占路径

- `lib/src/features/chat/application/chat_conversation_controller.dart`
- `lib/src/features/chat/presentation/`
- `lib/src/features/papers/presentation/widgets/paper_comments_sheet.dart`
- `test/chat_conversation_controller_test.dart`
- `test/paper_ai_*_test.dart`
- `test/ui_preview_test.dart`
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

- 已完成：创建独立分支和 worktree；完成移动端顶部栏、对话大纲、消息布局、推理卡片、消息操作栏、来源列表和 Composer。
- 已完成：根据验收反馈移除用户头像、朗读/翻译、预设问题、聊天管理/新建入口和生成中标签；增加标题编辑、主/论文会话副标题、最新消息操作限制、自适应 Composer 和网络头像。
- 已完成：本轮完整验证通过。
- 已完成：修复移动端回复中超宽行内 LaTeX 触发 `RenderLine overflow` 的问题，并增加 Markdown 回归测试。
- 已完成：通过 Computer Use 验收会话列表到主聊天的返回路径，聊天详情页恢复显式返回按钮。
- 已完成：根据“AI 会话 UI 丑”的反馈完成第二轮视觉收敛：降低粉色饱和度、统一圆角与间距、缩小操作图标、优化头像加载 fallback、Composer 和底部面板，并隐藏桌面预览滚动条。
- 已完成：根据后续验收反馈移除 Fork，Composer 的模型入口改为模型头像，输入框取消内部显示边框，复制消息时只复制最终回答、不复制 COT。
- 已完成：来源列表支持点击打开 http/https 链接，非法或无法打开的链接显示提示。
- 已确认：当前 PaperFlow 分支没有 AI 绘画入口或对应路由，不能在此构建中进入该页面。
- 下一步：由编排者复核第二轮 AI 会话视觉调整。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-04 | 只复刻移动端 UI | 用户明确不做桌面端 | 不实现永久侧边栏和宽屏布局 |
| 2026-08-04 | 保留 PaperFlow 业务控制器 | 目标是视觉复刻，不迁移 RikkaHub 后端架构 | 仅改 presentation 层和必要的展示状态 |
| 2026-08-04 | 只保留主会话和论文会话入口 | 用户不允许新建一般会话 | 移除聊天抽屉和新建聊天按钮；标题仍可编辑 |
| 2026-08-04 | 消息操作按角色和最新消息收敛 | 降低聊天操作噪声 | 用户只显示复制/最新修改；Assistant 只显示复制/最新重试/删除与 Fork 菜单 |
| 2026-08-04 | 未来能力暂不实现 | 多论文合并与会话引用需要新的上下文与持久化契约 | 仅记录为后续设计方向 |
| 2026-08-04 | 行内公式超出段落宽度时使用 `FittedBox(BoxFit.scaleDown)` | 公式本身不可断行，`Math.tex` 的自然宽度会触发 `RenderLine` 横向溢出 | 保持行内语义，同时在移动端宽度内缩放显示 |
| 2026-08-04 | 聊天详情页使用显式返回按钮，不恢复聊天管理抽屉 | 会话列表进入主/论文聊天后仍需要返回，但用户不需要左上角聊天管理 | 保留单一返回路径，继续移除新建会话与聊天抽屉 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `dart format` + `tool/verify_changed_dart_format.ps1` | 通过，14 个 Dart 文件格式检查通过 | 2026-08-04 |
| `git diff --check` | 通过 | 2026-08-04 |
| `flutter analyze` | 通过，无 issue | 2026-08-04 |
| 定向聊天 UI / 集成测试 | 通过，52 个测试 | 2026-08-04 |
| `flutter test` | 通过，253 个测试 | 2026-08-04 |
| `flutter build apk --debug --flavor development --dart-define=PAPERFLOW_ENV=development` | 通过，生成 development debug APK | 2026-08-04 |
| `flutter run -d windows` | 通过：用户确认后启动 Windows 验收窗口，完成 PaperFlow → ChatPaper → 主聊天路径检查 | 2026-08-04 |
| Computer Use：PaperFlow → ChatPaper → 主聊天 | 通过；确认主聊天顶部显示“返回”按钮，当前构建没有 AI 绘画入口 | 2026-08-04 |
| 第二轮 AI 会话视觉验收 | 通过：返回按钮、消息正文、推理面板、模型面板和自适应 Composer 均可见；模型面板与思考深度面板采用圆角底部面板 | 2026-08-05 |
| 后续 AI 会话验收反馈 | 已实现：移除 Fork、模型入口使用模型头像、输入框无内部显示边框、复制不包含 COT；系统提示词/个性化/Skills 仅记录为后续计划 | 2026-08-05 |
| 来源点击验收 | 通过：来源标题显示可点击样式，点击后打开对应 http/https 链接，并覆盖 Widget 测试 | 2026-08-05 |

## 审查结论

> 本轮完成提交前的人工 diff 审查，未发现阻断项。

- 审查日期：2026-08-04
- 阻断项：无
- 缺陷：移动端人工截图验收尚未执行；模型头像依赖网络。
- 结论：可合并，待编排者人工验收

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `8ab4cba` | `fix(chat): refine mobile chat acceptance UI` | 验收反馈修订与完整验证 | analyze 通过；252 个测试通过；development debug APK 构建通过 |
| `f9cc05e` | `fix(markdown): scale wide inline formulas on mobile` | 行内公式溢出修复 | analyze 通过；253 个测试通过；development debug APK 构建通过 |

## 交付记录（合并前补齐）

### 交付摘要

在上一轮 RikkaHub 移动端 UI 复刻基础上，根据验收反馈进一步收敛交互：用户侧只保留气泡和复制/最新修改，Assistant 侧只保留复制/最新重试/删除；移除聊天管理、新建聊天、预设问题和生成中标签；标题可编辑，主会话与论文会话显示不同副标题，Composer 改为自适应高度。

### 实际变更

- 领域与业务逻辑：无；仅使用现有 ChatConversationController 状态。
- 数据与基础设施：无。
- 界面与交互：调整移动端聊天壳、顶部栏、消息视图、推理卡片、来源和 Composer；移除抽屉/新建入口/预设问题；新增标题编辑、角色化消息操作、自适应输入区和网络模型头像。
- 测试与工具：更新聊天 UI Widget 测试，新增移动端聊天壳测试。
- 文档：本台账

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：无
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：未在真实 Android 设备上做截图级人工对照；模型头像依赖 DeepSeek 官方 favicon 网络可用性，失败时回退为内置图标；完整会话分支不在当前范围。当前 PaperFlow 也未包含 AI 绘画页面；如需该功能需要单独新增页面与入口。
- 回滚方式：revert 本分支提交，不涉及数据迁移

### 文档更新建议

- 本次只涉及移动端 ChatPaper presentation，不需要同步开发计划。

### 未完成与后续工作

- 由编排者启动 Android 移动端人工验收；根据截图对照继续微调尺寸、颜色和图标。
- 未来方向：支持一个会话关联多篇论文；合并会话时由 AI 总结多个会话并生成新的上下文。
- 未来方向：支持引用已有会话，把历史会话作为当前会话的可引用上下文。
- 未来方向：增加会话级系统提示词、个性化偏好和 Skills，并明确三者的作用域、优先级与安全边界。
