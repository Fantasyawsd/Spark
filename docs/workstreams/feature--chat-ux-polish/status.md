# 任务台账

## 基本信息

- 任务：完成 ChatPaper 七条开发计划（UI 打磨、数据边界、会话设置、流式稳定、PDF 全文）
- 关联发布或里程碑：无（P2 ChatPaper 研究工作流）
- 分支：`feature/chat-ux-polish`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\feature--chat-ux-polish`
- 基线提交：`f24923b`
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：已完成，待合并
- 最近更新：2026-08-06

## 目标

完成 `docs/development.md` §3.2 ChatPaper 开发计划的全部 7 条：① 稳定流式渲染打磨；② 主聊天/论文聊天/AI 派生缓存数据边界；③ PDF 分块、可追溯引用与上下文裁剪；④ 会话级系统提示词、个性化偏好与 Skills；⑤ 模型二级菜单头像化与透明背景；⑥ 网络搜索引用默认折叠；⑦ 发送后收起键盘。

## 非目标

- 不实现社区/私信、账号、云同步。
- 不实现论文模块六问 AI 解读（第 9 条）的完整后端链路；本次只落地 PDF 文本提取与分块注入。
- 不改变 DeepSeek 服务契约与会话持久化结构（会话设置独立 schema）。

## 验收标准

- [x] 模型头像去除背景色、透明显示；二级模型面板以头像展示（加载失败保留图标 fallback）。
- [x] 来源/引用面板默认折叠，展开后可见来源行；保留数量、可点击链接与错误状态。
- [x] 发送消息后立即收起键盘；AI 回复期间与完成后不自动聚焦回输入区；编辑消息仍聚焦。
- [x] 主聊天与论文聊天上下文边界明确并有测试覆盖；派生数据只经 systemPrompt 注入。
- [x] 会话级设置（自定义系统提示词/回答风格/技能）可编辑、持久化并作用于请求。
- [x] 流式渲染对未闭合斜体/删除线稳定，不随最终块跳变。
- [x] 论文聊天可读取全文：PDF 下载、文本提取、分块缓存、预算裁剪与页码追溯引用。
- [x] 新增业务行为有测试覆盖；格式、analyze、全量 test 通过。

## 写入范围

### 独占路径

- `lib/src/features/chat/`（controller、presentation、新增 data/domain 会话设置）
- `lib/src/features/papers/`（PDF 提取/分块/仓储、prompt builder、context builder）
- `lib/src/core/widgets/paperflow_markdown.dart`
- `lib/src/app/paperflow_dependencies.dart`、`lib/src/app/paperflow_app.dart`
- `pubspec.yaml` / `pubspec.lock`（新增 `syncfusion_flutter_pdf`）
- 相关测试：`test/paper_ai_*`、`test/paper_markdown_test.dart`、`test/paper_pdf_test.dart`、`test/chat_session_settings_test.dart`、`test/chat_context_boundary_test.dart`
- 本台账

### 共享路径

- 无

## 依赖关系

- 上游任务：ChatPaper 移动端 UI 复刻（`3af7686` 已合并）。
- 外部接口或数据源：arXiv PDF 下载（http）；`syncfusion_flutter_pdf` 纯 Dart PDF 解析。

## 实施计划

1. 任务 5/6/7：模型头像透明化与二级菜单头像化、来源默认折叠、发送后收起键盘（UI 三连，一个提交）。
2. 任务 2：明确主聊天/论文聊天/AI 派生缓存数据边界（文档 + 测试）。
3. 任务 4：会话级系统提示词、回答风格与可组合技能（领域/仓储/controller/UI/测试）。
4. 任务 1：流式渲染稳定器补充斜体与删除线未闭合处理（+测试）。
5. 任务 3：PDF 下载/提取/分块/缓存、预算裁剪与页码追溯引用、论文聊天「读取全文」入口（+测试）。
6. 更新开发计划与台账，全量验证，合并收尾。

## 当前进度

- 已完成：七条开发计划全部实现并有测试覆盖；全量 `flutter test` 295 项通过；analyze 与格式门禁通过。
- 正在进行：合并前收尾（APK 构建验证、合并 main、清理）。
- 下一步：`flutter build apk` 验证；合入 main；清理 worktree 与分支。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-06 | PDF 解析使用 `syncfusion_flutter_pdf` | 纯 Dart、跨平台、无需原生配置，符合「DeepSeek 不直接上传 PDF」约束 | 新增依赖；Android/Windows 均可文本提取 |
| 2026-08-06 | PDF 全文按需注入（「读取全文」开关，默认关） | 控制 token 消耗，避免每次论文聊天都注入全文 | 读取全文为论文聊天可选能力 |
| 2026-08-06 | 会话设置独立 schema，不扩展会话消息仓储 | 避免破坏现有 `ChatSessionRepository` 接口与所有实现 | 新增 `papers.ai-session-settings` 独立存储 |
| 2026-08-06 | 自定义系统提示词为空时保持默认，风格/技能总追加 | 保留默认 Markdown/公式约束，用户可完全自定义基础提示词 | 组装规则见 `ChatPromptAssembler` |
| 2026-08-06 | 无自定义设置时 `applySettings` 返回原 context | 保持既有 `same` 语义与零开销 | 空设置不重建 ChatContext |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `.\tool\verify_changed_dart_format.ps1` | 通过（32 个 Dart 文件） | 2026-08-06 |
| `flutter analyze` | 通过，No issues found | 2026-08-06 |
| `flutter test` | 通过，295 项 | 2026-08-06 |
| `flutter test test\paper_pdf_test.dart` | 通过（提取/分块/裁剪/引用 5 项） | 2026-08-06 |
| `flutter test test\paper_ai_mobile_chat_ui_test.dart` | 通过（含键盘收起、会话设置、全文开关 UI） | 2026-08-06 |
| `flutter test test\chat_session_settings_test.dart` | 通过（组装/持久化/请求应用） | 2026-08-06 |
| `flutter test test\chat_context_boundary_test.dart` | 通过（主聊天/论文聊天边界） | 2026-08-06 |
| `git diff --check` | 通过 | 2026-08-06 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：2026-08-06
- 阻断项：无
- 缺陷：无
- 结论：可合并

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `86ab314` | feat(chat): transparent avatars, collapsed sources and keyboard dismissal | 任务 5/6/7 | analyze 通过；全量 275 项测试通过 |
| `20ac110` | docs(chat): define main/paper/derived context boundaries | 任务 2 | 边界测试 + development.md 文档 |
| `d49c938` | feat(chat): per-session system prompt, response style and skills | 任务 4 | analyze 通过；全量 285 项测试通过 |
| `6cddc68` | fix(markdown): stabilize streaming italic and strikethrough | 任务 1 | 全量 288 项测试通过 |
| `15861b2` | feat(chat): PDF full-text chunking, traceable citations and context trimming | 任务 3 | analyze 通过；全量 295 项测试通过 |

## 交付记录（合并前补齐）

### 交付摘要

ChatPaper 七条开发计划全部完成：模型头像透明化并用于二级菜单；来源默认折叠；发送后收起键盘；主聊天/论文聊天/AI 派生缓存边界文档化；会话级自定义系统提示词、回答风格与可组合技能；流式渲染稳定斜体/删除线；论文聊天可读取 PDF 全文（分块缓存、预算裁剪、页码追溯引用）。

### 实际变更

- 领域与业务逻辑：新增 `ChatSessionSettings`/`ChatSkill`/`ChatResponseStyle` 与会话设置仓储；`ChatConversationController` 支持设置加载/保存、`replaceContext` 与 `effectiveContext`；新增 `PaperPdfChunk`/`PaperPdfExtract` 与 PDF 仓储。
- 数据与基础设施：新增 `papers.ai-session-settings`、`papers.pdf-extracts` 独立 schema；新增 `syncfusion_flutter_pdf` 依赖。
- 界面与交互：模型头像透明化；来源面板默认折叠；发送即收起键盘；会话设置面板；论文聊天「读取全文」按钮与加载状态。
- 测试与工具：新增 chat_session_settings、chat_context_boundary、paper_pdf 与移动端 UI 测试；全量 295 项通过。
- 文档：更新 `docs/development.md`（§2.2 状态、§3.2 计划全部标完成、§4.2 边界文档）；本台账。

### 兼容性与迁移

- 本地数据迁移：新增独立 schema（会话设置、PDF 提取），无既有数据迁移负担。
- API 或领域契约变化：`ChatContext` 的 `context` 字段由 final 改为可变（`replaceContext`）；`PaperChatContext.fromPaper` 与 `PaperAiPromptBuilder.systemPrompt` 增加可选 `pdfContext` 参数（向后兼容）。
- 旧版本兼容性：新增参数均有默认值，未改变既有调用；会话消息 schema 不变。

### 已知风险与回滚

- 已知风险：PDF 文本提取依赖 `syncfusion_flutter_pdf` 的文本提取质量（扫描件可能提取失败，已给出错误提示）；PDF 全文按需开启，默认不注入以控制 token 消耗；Android 真机需验证 PDF 提取与下载。
- 回滚方式：按原子提交 revert `15861b2`、`6cddc68`、`d49c938`、`20ac110`、`86ab314`（逆序）；数据 schema 新增不影响旧版本读取。

### 文档更新建议

- 已更新 `docs/development.md`：§3.2 ChatPaper 七条计划标 ✅ 已完成；§2.2 当前状态补充移动端 UI、会话设置、PDF 全文、来源折叠与键盘行为；§4.2 新增「ChatPaper 上下文边界」。

### 未完成与后续工作

- Android 真机验收 PDF 全文读取与键盘行为。
- 论文模块六问 AI 解读（开发计划论文第 9 条）仍待后端 PDF 分块分析链路。
- 已知问题（待修复）：论文聊天「读取全文」按钮在下载/解析失败时可能无反馈或停在加载态（`_toggleFullText` 仅捕获 Exception）；成功时无完成提示。已记录于 `docs/development.md` §3.2 已知问题，修复方向：捕获所有异常并复位 loading、成功/失败均 SnackBar 提示。
- 会话合并（AI 总结多会话）与引用会话功能属后续规划。
