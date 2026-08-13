# ChatPaper 消息视图边界与粒度重构台账

> 本台账记录 DeepSeek 报告逐步修复链的第三批任务。本批直接基于第二批最终审查提交创建；按编排者要求不合入 `main`，完成后继续作为下一批修复 worktree 的基线。

## 基本信息

- 任务：拆分 ChatPaper 消息视图并移除展示层外链平台直连
- 关联发布或里程碑：代码质量加固，不绑定发布版本
- 分支：`refactor/chat-message-view-boundaries`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-3`
- 基线提交：`175f26ac469fb6817701570858d49b990bb0ce8a`
- 负责人：Codex（Fantasy 编排）
- 状态：规划中
- 最近更新：`2026-08-13 15:48`（Asia/Shanghai）

## 目标

将 923 行的 `paper_ai_message_view.dart` 拆成职责清晰、可独立测试的 ChatPaper 展示组件，并由应用组合根注入来源链接打开能力、复用单一 HTTP(S) URI 校验规则，消除 presentation 对 `url_launcher` 的直接依赖与复制校验，同时保持消息渲染和交互契约不变。

## 非目标

- 本批不拆分 `paper_ai_chat_screen.dart`，不处理其中 Android IME 平台类、`SystemChannels.textInput`、多流程 State 或会话设置 sheet；这些属于下一批独立任务。
- 不修改 ChatConversationController、会话持久化、DeepSeek 请求、PDF 全文加载或 ChatPaper 上下文语义。
- 不重设计消息视觉、操作入口、推理折叠、来源折叠、多选、复制、重试、编辑或删除行为。
- 不建立全应用日志体系；链接打开异常的可观测性随报告中的日志专项处理。
- 不启动 Windows App、不做人工验收、不执行浏览器自动化。
- 不合入 `main`，不执行常规 `/finish`，不清理前两批或本批 worktree。

## 验收标准

- [ ] `paper_ai_message_view.dart` 只负责消息类型选择与选择态装配；用户/助手气泡、操作区、推理面板和来源面板按单一职责拆到 chat feature 内部文件，原 923 行文件显著缩小，所有结果文件均可一次理解且不保留超长 `build`。
- [ ] `lib/src/features/chat/presentation/` 不再导入 `package:url_launcher` 或直接调用 `launchUrl`；来源链接只能通过注入的窄回调打开，未注入时不产生隐式平台回退。
- [ ] HTTP(S) URI 校验只有一个实现：chat 来源与 papers 链接共同复用 core 中的纯校验函数；空值、空 host、非 HTTP(S) scheme 均不可打开。
- [ ] 生产组合根为论文全屏聊天、主聊天和论文内嵌讨论三条路径注入现有平台链接服务；有效来源仍可外部打开，返回 `false` 或抛异常时仍显示“无法打开来源链接”。
- [ ] 消息复制不包含 reasoning、推理/来源默认折叠与展开、流式状态、多选、重试、编辑和删除入口等既有行为保持不变。
- [ ] 新增或扩充 Widget/单元测试，覆盖有效来源回调、非法 URI 禁用、缺少 opener 禁用、打开失败反馈及拆分后的主要交互。
- [ ] 相关定向测试、Dart 格式、`flutter analyze`、`flutter test` 和 `git diff --check` 通过。

## 写入范围

### 独占路径

- `lib/src/core/platform/` 中新增的共享外链 URI 校验文件
- `lib/src/features/papers/domain/paper_link_service.dart`（仅改为复用共享校验）
- `lib/src/features/chat/presentation/widgets/paper_ai_message_view.dart`
- `lib/src/features/chat/presentation/widgets/paper_ai_message_*.dart`（本批新增拆分组件）
- `lib/src/features/chat/presentation/widgets/paper_ai_content.dart`（仅透传外链回调）
- `lib/src/features/chat/presentation/paper_ai_chat_screen.dart`（仅新增并透传外链回调）
- `lib/src/features/chat/presentation/paper_ai_discussion_view.dart`（仅新增并透传外链回调）
- `lib/src/features/chat/presentation/main_ai_chat_screen.dart`（仅新增并透传外链回调）
- `test/paper_ai_message_view_test.dart`
- `test/paper_ai_content_test.dart`
- 与三条生产聊天入口外链注入直接对应的定向测试
- `docs/workstreams/refactor--chat-message-view-boundaries/status.md`

### 共享路径

- `lib/src/app/spark_app.dart`：仅使用现有 `_linkService.open` 为三条 ChatPaper 入口接线，不在本批拆分应用壳或增加其他流程。

## 依赖关系

- 上游任务：第二批 `refactor/architecture-boundary-hardening@175f26a`，本 worktree 从其最终审查提交直接创建。
- 历史重叠任务：`fix/chat-message-actions` 已合并并归档；本批必须保持其“内嵌讨论隐藏无效编辑/删除入口，全屏聊天保留完整入口”的契约。
- 外部接口或数据源：无真实网络；平台链接能力通过注入 fake/callback 验证。

## 实施计划

1. 为有效/非法来源、缺少 opener、打开失败和既有消息交互补齐 characterization tests，先证明当前隐式平台回退和重复校验边界。
2. 在 `core/platform` 建立纯 HTTP(S) URI 校验事实源，让 papers 的 `validPaperUri` 保持兼容并委托该实现，chat 直接复用共享规则。
3. 按消息装配、气泡与操作、推理、来源四个职责拆分 `paper_ai_message_view.dart`，控制文件和 `build` 粒度，不改变 key、语义标签或视觉令牌。
4. 删除 chat presentation 的 `url_launcher` 依赖和 fallback，通过 `PaperAiContent`、全屏/主聊天、内嵌讨论与 `SparkShell` 透传 `_linkService.open`。
5. 运行消息视图、内容、全屏聊天、内嵌讨论和组合根定向回归，核对文件规模、旧符号与平台调用检索，再执行格式和静态分析。
6. 形成原子代码提交并更新台账，之后依次进入 `/test` 和只读 `/review`；不进入合并 `main` 的 `/finish`。

## 当前进度

- 已完成：读取 `/start` 工作流、项目必读文档、DeepSeek 原报告及直接重叠的 `fix/chat-message-actions` 归档台账。
- 已完成：确认报告条目仍成立：`paper_ai_message_view.dart` 为 923 行，直接 import `url_launcher` 并在无 callback 时调用 `launchUrl`，`_validUri` 与 `validPaperUri` 规则重复。
- 已完成：确认现有 `PaperLinkService` 已由组合根注入 papers 路径，ChatMessageView/PaperAiContent 已具备可空 `onOpenSource` 通道，但三个生产聊天入口均未接线，因此当前依赖展示层 fallback。
- 已完成：从第二批最终提交 `175f26a` 创建 `agent-3` 与 `refactor/chat-message-view-boundaries`；`main@5578a77` 未变化。
- 正在进行：第三批任务台账初始化，尚未修改功能代码。
- 下一步：触发 `/develop`，先补齐来源链接 characterization tests，再开始共享校验与组件拆分。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 第三批只处理消息视图，不同时拆分 906 行聊天屏幕 | 两个高危文件职责与验证风险不同；串行小批次更易审查和回滚 | `paper_ai_chat_screen.dart` 只允许窄参数透传，IME/设置/state 拆分留到第四批 |
| 2026-08-13 | 复用现有组合根链接服务，通过回调注入 chat | `SparkDependencies` 已持有平台适配器，ChatMessageView/PaperAiContent 已有 callback 形态 | 无需在 Widget 创建插件或新增第二套平台实现 |
| 2026-08-13 | 把通用 HTTP(S) URI 校验放入 core，保留 `validPaperUri` 兼容入口 | papers 与 chat 两个独立模块真实复用同一纯规则，符合 core 边界；直接让 chat 深导入 papers domain 语义不当 | 消除复制校验且不强迫本批重命名所有 PaperLinkService API |
| 2026-08-13 | 不进行人工验收或合并 | 编排者明确要求自动修复链保留在 worktree | 以自动化测试和只读审查作为证据，完成后串联下一 worktree |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `/start` Git 预检 | 控制工作树 `main@5578a77` 干净；第二批 `agent-2@175f26a` 干净；目标分支与 `agent-3` 路径均不存在 | 2026-08-13 |
| `git worktree add ..\agent-3 -b refactor/chat-message-view-boundaries 175f26a...` | 成功；第三批完整继承前两批修复，`main` 未变化 | 2026-08-13 |
| 报告与源码定向检索 | 923 行、presentation 直连 `url_launcher`、重复 URI 校验三项均仍存在；现有 callback 未在生产入口注入 | 2026-08-13 |
| 相关历史台账核对 | `fix/chat-message-actions` 已归档；内嵌/全屏消息操作显隐契约纳入本批回归范围 | 2026-08-13 |

## 审查结论

> 尚未进入 `/review`。

- 审查日期：不适用
- 阻断项：待审查
- 缺陷：待审查
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

本批尚未进入实现阶段。目标交付结果为消息视图职责拆分、展示层平台直连消失、生产来源链接保持可用且交互无回归；真实结果将在各检查点持续更新。

### 实际变更

- 领域与业务逻辑：待实现。
- 数据与基础设施：待实现。
- 界面与交互：预期无可观察变化。
- 测试与工具：待实现。
- 文档：持续更新本台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：计划保留 `validPaperUri` 与现有链接服务契约；Chat presentation 构造器将增加可空 callback 透传。
- 旧版本兼容性：无数据影响；生产三条入口完成注入后用户行为保持不变。

### 已知风险与回滚

- 已知风险：私有 Widget 拆分可能造成 key、语义、AnimatedSize/Timer 生命周期或操作入口显隐漂移，必须由现有与新增 Widget 测试覆盖。
- 回滚方式：按检查点逆序 `git revert`；无数据迁移。

### 文档更新建议

- 本批属于内部结构和平台边界修复，不预期改变 `docs/development.md` 的功能路线图状态。

### 未完成与后续工作

- 下一批继续处理 `paper_ai_chat_screen.dart` 的 Android IME 平台边界、State 多流程与设置 sheet 粒度。
- 报告中的状态双源、日志、应用壳、ThemeController、其他大文件、数据建模、重复代码、死代码、测试缺口和服务端问题继续由后续串联 worktree 处理。

## 合并归档

> 编排者明确要求本修复链不合入 `main`，因此本节当前不适用；不预填集成提交、合并时间或 main 验证。

- 最终状态：未合并，第三批规划中
- 合入分支：不适用
- 最终集成提交：不适用
- Pull Request：不适用
- 合并时间：不适用
- main 集成验证：不适用
- 开发计划更新：本批不改变功能路线图状态
- 最终后续项：完成后以本批最终提交创建下一修复 worktree
