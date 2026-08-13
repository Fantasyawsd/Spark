# ChatPaper 屏幕状态与平台边界重构台账

> 本台账记录 DeepSeek 报告逐步修复链的第四批任务。本批直接基于第三批最终审查提交创建；按编排者要求不合入 `main`，完成后继续作为下一批修复 worktree 的基线。

## 基本信息

- 任务：拆分 ChatPaper 屏幕职责并隔离 Android IME 平台通道
- 关联发布或里程碑：代码质量加固，不绑定发布版本
- 分支：`refactor/chat-screen-boundaries`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-4`
- 基线提交：`2d23c6c955f682dccae4383fb447ff994c27877d`
- 负责人：Codex（Fantasy 编排）
- 状态：开发实现完成，待 `/test`
- 最近更新：`2026-08-13 16:27`（Asia/Shanghai）

## 目标

将 909 行的 `paper_ai_chat_screen.dart` 收敛为页面组合与会话协调入口：把 Android IME 布局算法、系统键盘关闭通道、标题/全文 AppBar、消息多选状态与操作栏、会话设置 sheet 拆到职责明确且可独立验证的 ChatPaper presentation 组件，同时保持既有键盘几何、跨页面续答、消息操作、全文加载、设置与标题交互不变。

## 非目标

- 不改变 `_ImeAnchoringScrollController` 已通过 Android 真机与自动化验收的差值锚定算法、160px 跟随阈值、输入栏独立平移或 `adjustNothing` 清单配置。
- 不删除 `TextInput.hide` 的 Android 残留输入法兜底；只把平台通道访问移出页面 Widget 并建立可替换边界。
- 不修改 `ChatConversationController`、`ChatConversationCoordinator`、DeepSeek 请求、消息持久化、跨界面续答或页面/控制器所有权语义。
- 不修复开发计划中暂缓的“读取全文”下载/解析覆盖缺口；本批只迁移并保持现有成功、context mismatch 与异常反馈行为。
- 不重设计 AppBar、消息多选、会话设置、Composer 或任何视觉令牌；`paper_ai_composer.dart` 的 181 行 build/内联 sheet 属后续独立问题。
- 不实现 side chat、enterToSend、六问 AI 解读或其他新功能。
- 不启动 Windows App、不做人工验收、不执行浏览器自动化。
- 不合入 `main`，不执行常规 `/finish`，不清理前四个 worktree。

## 验收标准

- [x] `paper_ai_chat_screen.dart` 只保留页面组合、会话控制器生命周期与少量跨组件协调；不再内嵌 Android IME 类、会话设置 sheet、标题/全文 AppBar 实现或消息多选控件，文件规模显著下降且主要 `build` 可一次理解。
- [x] `paper_ai_chat_screen.dart` 不再 import `flutter/services.dart`、访问 `SystemChannels` 或直接 `invokeMethod('TextInput.hide')`；系统键盘兜底位于 chat presentation 的窄平台适配器，并可由测试替换。
- [x] 四个 Android IME 布局/滚动类迁移到单一职责文件；Android 顶栏与消息视口固定、底栏随 inset 平移、长对话滚动按差值锚定以及非 Android 默认 inset 行为完全保持。
- [x] 标题编辑与全文加载状态由聚合 AppBar 组件拥有；消息选择集合/启停由独立 presentation controller 拥有；屏幕 State 不再同时持有这三类独立流程的字段。
- [x] 会话设置 sheet 拆为独立组件并将 138 行 `build` 分解为短区块；自定义 prompt、回答风格、Skills 选择与保存契约不变。
- [x] 原有 ValueKey、可访问性语义、移动/桌面发送焦点、编辑最新提示、多选配对与批量删除、预览切换、清空确认、全文三条反馈路径均保持。
- [x] 新增或扩充独立测试覆盖键盘适配器、消息选择 controller 与拆分组件；既有 Android IME、键盘交互、移动聊天 UI 和后台续答定向测试通过。
- [ ] 相关定向测试、Dart 格式、`flutter analyze`、`flutter test` 和 `git diff --check` 通过。

## 写入范围

### 独占路径

- `lib/src/features/chat/presentation/paper_ai_chat_screen.dart`
- `lib/src/features/chat/presentation/platform/` 中本批新增的键盘与 IME presentation 适配文件
- `lib/src/features/chat/presentation/paper_ai_message_selection_controller.dart`（本批新增）
- `lib/src/features/chat/presentation/widgets/paper_ai_chat_app_bar.dart`（本批新增）
- `lib/src/features/chat/presentation/widgets/paper_ai_message_selection_bar.dart`（本批新增）
- `lib/src/features/chat/presentation/widgets/paper_ai_session_settings_sheet.dart`（本批新增）
- 与上述新边界直接对应的新增测试文件
- `test/android_keyboard_window_config_test.dart`（仅补充迁移后的 IME 契约）
- `test/paper_ai_chat_keyboard_interactions_test.dart`（仅补充平台适配器注入契约）
- `test/paper_ai_mobile_chat_ui_test.dart`（仅补充标题/全文/设置/多选拆分回归）
- `docs/workstreams/refactor--chat-screen-boundaries/status.md`

### 共享路径

- 无。预计不需要修改 `SparkApp`、组合根、领域/application 层、Android 清单或其他 feature；若实现证据表明必须扩展，先更新台账再写入。

## 依赖关系

- 上游修复链：第三批 `refactor/chat-message-view-boundaries@2d23c6c`；本 worktree 完整继承前三批修复与审查证据。
- 重叠历史任务：`fix/android-keyboard-jank`、`feature/chat-keyboard-interactions`、`feature/chat-background-completion` 均已合并归档；本批必须保持其 IME 几何、移动/桌面焦点和页面仅解绑监听的生命周期契约。
- 外部接口或数据源：Flutter `SystemChannels.textInput` 与 `MediaQuery.viewInsets`；无真实网络、文件、数据库或设备操作。

## 实施计划

1. 以现有 Android IME、键盘交互、移动聊天 UI 与后台续答测试建立拆分前 characterization 基线，并为可注入键盘关闭边界和纯消息选择状态补红测。
2. 抽出键盘关闭平台适配器与 Android IME 布局/滚动文件，保持算法逐行等价，让页面只组合这些对象。
3. 抽出消息选择 controller、选择态 AppBar/底栏，并用独立单测锁定助手消息自动配对前一条用户消息、切换与清空语义。
4. 抽出标题/全文 AppBar，使标题和全文 loading/enabled 状态由子组件拥有；保留页面向会话控制器提交 context 的窄回调。
5. 抽出会话设置 sheet 并拆短 build；页面仅负责展示结果后调用 `updateSettings`。
6. 复跑全套 ChatPaper 定向测试，核对文件/函数规模、平台符号残留、依赖方向与 key，再执行格式和静态分析。
7. 形成原子代码提交并更新台账，之后依次进入 `/test` 和只读 `/review`；不进入合并 `main` 的 `/finish`。

## 当前进度

- 已完成：按 `/start` 顺序读取 README、文档索引、开发计划、三份强制规范、DeepSeek 原报告及直接重叠的三份 ChatPaper 历史台账和第三批台账。
- 已完成：确认报告条目仍成立：目标文件现为 909 行，内嵌 4 个 Android IME 类，页面直接调用 `SystemChannels.textInput`，State 同时维护标题、全文、多选、预览与编辑流程，设置 sheet 的 build 仍为约 138 行。
- 已完成：确认现有回归基础覆盖 Android 8 帧 inset 几何与滚动锚定、桌面/移动发送焦点、多选收键盘、标题编辑、设置保存、全文成功/context mismatch/异常和跨界面续答。
- 已完成：从第三批最终审查提交 `2d23c6c` 创建 `agent-4` 与 `refactor/chat-screen-boundaries`；`main@5578a77` 未变化。
- 已完成：拆分前 characterization 基线 25 项通过；新增红测准确暴露键盘适配器、选择 controller 与构造注入缺失。
- 已完成：将 `TextInput.hide` 三层关闭语义集中到可注入的 `PaperAiKeyboardDismissal`，页面移除 `flutter/services.dart` 与平台通道访问。
- 已完成：将 Android 底栏平移、IME spacer、滚动 controller/position 原样迁移到 `paper_ai_ime_layout.dart`，160px 阈值和差值修正未改变。
- 已完成：将消息配对选择规则迁入独立 `PaperAiMessageSelectionController`，选择态 AppBar 与底栏迁入专用组件。
- 已完成：聚合 AppBar 自持标题与全文 loading/enabled 状态，并在内部切换多选外观，避免进入多选导致状态丢失；会话设置 sheet 已拆为短区块组件。
- 已完成：主页面由 909 行降至 343 行；新增边界与组件测试，定向套件 31 项、架构测试 23 项及 `flutter analyze` 均通过。
- 正在进行：`/develop` 已完成并形成原子代码提交，等待独立 `/test` 完整门禁。
- 下一步：触发 `/test`，执行 changed Dart format、`flutter analyze` 与完整 `flutter test`，记录证据后再进入只读 `/review`。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 第四批完整处理报告高危项 #3，而不是只移动大段代码 | 报告同时指出平台直连、文件粒度、State 多流程和超长设置 build；只做文件搬运无法真正消除职责耦合 | 验收同时约束平台适配、状态所有权和组件粒度 |
| 2026-08-13 | 保留已验收 IME 算法，仅迁移所有权 | `fix/android-keyboard-jank` 经四轮真机反馈与确定性几何测试收敛，算法变化风险高且不属于报告问题 | 新文件必须保持 delta/threshold/correction 与 Android/非 Android 分支等价 |
| 2026-08-13 | `TextInput.hide` 保留但通过窄 presentation 平台适配器调用 | 历史任务确认它是 Android 焦点转移后的必要兜底；问题是 Widget 直接触碰通道，不是兜底能力本身 | 页面可注入 fake，平台通道集中在单一文件，不下沉到业务 domain |
| 2026-08-13 | 标题/全文状态由 AppBar 子组件拥有，消息选择由独立 controller 拥有 | 三类状态分别只影响 AppBar 或选择模式，放在页面 State 会让任一修改触碰无关流程 | 页面仅保留会话生命周期、Composer 编辑/发送与预览协调 |
| 2026-08-13 | 不进行人工验收或合并 | 编排者明确要求自动修复链保留在 worktree | 以自动化测试和只读审查作为证据，完成后串联下一 worktree |
| 2026-08-13 | 聚合 AppBar 内部切换普通/选择外观，不在 Scaffold 层替换组件类型 | 标题与全文状态下沉后仍必须跨多选模式存续；父级替换 AppBar 会销毁其 State | 新增组件测试锁定标题和全文已加载状态在多选往返后保持 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `/start` Git 预检 | 控制工作树 `main@5578a77` 干净；第三批 `agent-3@2d23c6c` 干净；目标分支与 `agent-4` 路径均不存在 | 2026-08-13 |
| `git worktree add ..\agent-4 -b refactor/chat-screen-boundaries 2d23c6c...` | 成功；第四批完整继承前三批修复，`main` 未变化 | 2026-08-13 |
| 报告与源码定向检索 | 909 行、4 个内嵌 IME 类、页面平台通道、5 类 UI 流程与超长 settings build 均仍存在 | 2026-08-13 |
| 重叠历史台账核对 | 锁定 `fix/android-keyboard-jank` 的 IME 算法、`feature/chat-keyboard-interactions` 的焦点/三层关闭、`feature/chat-background-completion` 的控制器所有权契约 | 2026-08-13 |
| 拆分前 characterization：4 个 ChatPaper 测试文件 | 25 项通过；覆盖 Android IME、桌面/移动焦点、标题/设置/全文、多选与后台续答 | 2026-08-13 |
| 新增边界红测 | 按预期编译失败：缺少键盘适配器、选择 controller 与 `PaperAiChatScreen.keyboardDismissal` 注入点 | 2026-08-13 |
| 新增键盘适配器、选择 controller 与键盘交互测试 | 8 项通过；确认三层关闭调用、助手配对前一用户消息、选择切换/清空及注入调用 | 2026-08-13 |
| AppBar 状态生命周期组件测试 | 1 项通过；编辑标题与全文已加载状态在普通/多选外观往返后保持 | 2026-08-13 |
| ChatPaper 最终定向套件 | 31 项通过；Android 几何/锚定、键盘、移动 UI、后台续答及三个新增边界文件均通过 | 2026-08-13 |
| `flutter test test/architecture_test_support_test.dart test/architecture_boundaries_test.dart` | 23 项通过；依赖方向、循环、公共入口与跨 feature 边界均无回归 | 2026-08-13 |
| `flutter analyze` | 通过，No issues found | 2026-08-13 |
| 结构与规模检查 | 页面 343 行；AppBar 223 行、设置 sheet 222 行、IME 文件 111 行；页面无 `flutter/services`、`SystemChannels`、内嵌 IME/settings/selection 状态符号 | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

> 尚未进入 `/review`。

- 审查日期：不适用
- 阻断项：待审查
- 缺陷：待审查
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `020cf3a` | `文档（台账）：启动聊天屏幕边界重构` | `/start` | 基于第三批最终提交建立第四批 worktree、范围、验收与风险台账 |
| `142e8b9` | `重构（ChatPaper）：拆分会话页展示与平台边界` | `/develop` | 定向 31 项、架构 23 项、analyze 与 diff check 通过；页面 909→343 行 |

## 交付准备（合并前收集）

### 交付摘要

ChatPaper 页面已收敛为会话控制器生命周期、Composer 编辑/发送和少量跨组件协调入口；Android IME、系统键盘通道、标题/全文 AppBar、消息选择及设置 sheet 已按职责拆分，既有交互、键盘几何和后台续答契约由 31 项定向测试保持。当前代码提交为 `142e8b9`，尚待独立完整 `/test` 与 `/review`。

### 实际变更

- 领域与业务逻辑：无变化；消息选择配对规则从页面 State 原样迁入 presentation controller。
- 数据与基础设施：无变化；新增 chat presentation 键盘平台适配器，不改变外部服务或持久化。
- 界面与交互：无预期可观察变化；AppBar、选择栏与设置 sheet 原样组件化，IME 算法原样迁移。
- 测试与工具：新增键盘适配器、选择 controller 和 AppBar 生命周期测试，并扩充键盘交互测试的注入断言。
- 文档：本台账已记录实现、验证与提交证据。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：`PaperAiChatScreen` 增加带生产默认值的可选键盘关闭适配器注入；不改变 Chat domain/application 契约或现有调用方。
- 旧版本兼容性：无持久化或网络协议影响；生产默认适配器保持原行为。

### 已知风险与回滚

- 已知风险：IME 类虽保持算法等价，仍需由 `/test` 完整回归与 `/review` 复核；标题/全文在多选切换时的状态易失风险已由聚合 AppBar 内部切换和新增组件测试消除。
- 回滚方式：按检查点逆序 `git revert`；无数据迁移。

### 文档更新建议

- 本批属于内部结构和平台边界重构，不预期改变 `docs/development.md` 的功能路线图状态。

### 未完成与后续工作

- 下一批继续处理报告高危项 #4：`followed` 关注状态双源。
- `paper_ai_composer.dart`、`chat_conversation_controller.dart` 等中危粒度问题及日志、应用壳、ThemeController、数据建模、重复代码、死代码、测试缺口和服务端问题继续由后续串联 worktree 处理。

## 合并归档

> 编排者明确要求本修复链不合入 `main`，因此本节当前不适用；不预填集成提交、合并时间或 main 验证。

- 最终状态：未合并，第四批开发完成、待 `/test`
- 合入分支：不适用
- 最终集成提交：不适用
- Pull Request：不适用
- 合并时间：不适用
- main 集成验证：不适用
- 开发计划更新：本批不改变功能路线图状态
- 最终后续项：完成后以本批最终提交创建下一修复 worktree
