# 任务台账

## 基本信息

- 任务：修复论文摘要中的行内公式断行
- 关联发布或里程碑：不关联发布（日常缺陷修复）
- 分支：`fix/inline-math-flow`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\fix--inline-math-flow`
- 基线提交：`63c00491503ad4fdad8c2f213c7d240f18a4bc1f`（`origin/main`）
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：待合并
- 最近更新：2026-08-04 03:58

## 目标

让论文 Abstract 和其他共用 Markdown 场景中的 `$...$` 公式参与同一段文字的真正行内排版，能够使用前文最后一行的剩余空间，并与紧邻标点和后文保持连续，不再被强制拆成独立行。

## 非目标

- 不修改摘要来源、arXiv 数据契约或缓存结构。
- 不重做论文阅读页布局、字体或行宽。
- 不实现超长公式内部的自动断行算法。
- 不改变 `$$...$$` / `\[...\]` 块公式的展示语义。
- 不修改 community、messages 或其他无关业务模块。

## 验收标准

- [x] 在受限宽度下，前文已经折行但末行仍有空间时，普通 `$...$` 公式接续在该末行，而不是另起一行。
- [x] 行内公式与其后的逗号、句号和正文处于同一段排版流，不产生截图中的孤立标点。
- [x] 公式保持正确 LaTeX 样式；`$$...$$` 块公式仍按块展示。
- [x] Abstract 文本仍可选择；论文阅读和 ChatPaper 共用 Markdown 路径无现有行为回归。
- [x] 新增回归测试先稳定复现缺陷，修复后通过；现有 Markdown 测试通过。
- [x] 格式检查、`flutter analyze`、全量 `flutter test` 和 development APK 构建通过。

## 写入范围

### 独占路径

- `lib/src/core/widgets/paperflow_markdown.dart`
- `test/paper_markdown_test.dart`
- `docs/workstreams/fix--inline-math-flow/status.md`

### 共享路径

- `docs/development.md`：仅在 `/finish` 同步 Markdown/公式稳定性状态；当前无已知并行写入，合并前重新核对。
- `pubspec.yaml` / `pubspec.lock`：仅在现有依赖无法提供正确行内排版且替代方案经过验证时修改；默认不引入新依赖。

## 依赖关系

- 上游任务：`746098a` 已移除 LaTeX 公式外层横向滚动，但未解决自定义 Widget 被 `Wrap` 分段布局的问题。
- 外部接口或数据源：无；涉及本地 Flutter 包 `flutter_markdown_plus` 与 `flutter_math_fork` 的渲染行为。

## 实施计划

1. 将最小复现固化为 Widget 回归测试：前文先折行、末行留有空间，断言行内公式占用该末行并保持邻接标点连续；确认测试在基线失败。
2. 比较三条实现路径：现有 Markdown builder 扩展、统一 `InlineSpan` 段落渲染、依赖升级/替换；选择能保留块级 Markdown、文本选择与公式语义的最小可靠方案。
3. 实现真正的行内排版，补充普通公式、连续标点、块公式和选择能力测试。
4. 运行定向格式、分析和测试，形成原子提交；随后执行完整验证门禁、只读审查和收尾合并。

## 当前进度

- 已完成：`/start` 全部步骤；失败回归测试；真正的 `InlineSpan` 段落排版实现；邻接标点、块公式、选择能力与 ChatPaper 定向回归；功能提交 `4756631`。
- 正在进行：`/review` 已完成，进入 `/finish` 合并与清理。
- 下一步：补齐交付记录，核对完成定义，合入 `main` 并清理 worktree/分支。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-04 | 本任务不关联发布版本 | 当前为 `0.0.1+1` 未发布阶段的日常兼容性缺陷修复 | 不更新版本号、CHANGELOG 或发布归档 |
| 2026-08-04 | 以真实布局坐标作为核心验证证据 | 现有测试只检查公式外层没有滚动容器，无法捕获截图中的断行 | 回归测试必须验证前文末行与公式的垂直重叠或等价的真实行内布局结果 |
| 2026-08-04 | 保留 `$...$` 与 `$$...$$` 的语义区分 | 缺陷只针对行内公式，不能用全部转纯文本或全部块级展示规避 | 实现需同时覆盖行内和块级公式 |
| 2026-08-04 | 让 LaTeX builder 返回含 `WidgetSpan(Math.tex)` 的 `Text.rich` | `flutter_markdown_plus` 会合并相邻文本节点，而直接返回 `Math` 会成为 `Wrap` 的独立子项 | 前文、公式和后文进入同一 `RenderParagraph`；无需 fork、升级或新增依赖 |
| 2026-08-04 | Markdown 内部统一使用 `Text.rich`，以 `SelectionArea` 提供选择 | `Text.rich` 支持嵌入 `WidgetSpan`，同时 `SelectionArea` 可保留 Abstract 文本选择；`selectable=false` 用 `SelectionContainer.disabled` 保持 ChatPaper 语义 | 论文 Abstract 可选择，AI 流式消息仍保持不可选择且不重建选择树 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 诊断最小 Widget 用例（前文折行后接 `$\beta > 2$`） | 基线稳定失败：公式没有统一 `Text` 段落祖先，而是 `Wrap` 中与前后文本并列的独立 Widget | 2026-08-04 |
| `flutter test test\paper_markdown_test.dart --plain-name "inline formulas render without a wrapping scroll view"` | 基线通过，但仅证明无滚动容器，不能证明真正行内布局 | 2026-08-04 |
| `flutter test test\paper_markdown_test.dart --plain-name "wrapped text keeps inline formulas and punctuation in one flow"` | 修复后通过；320px 下前词、公式 Widget 与逗号的实际行框垂直重叠，且统一段落序列为“前文 + WidgetSpan + 逗号 + 后文” | 2026-08-04 |
| `.\tool\verify_changed_dart_format.ps1` | 通过：2 个 Dart 文件，0 个需改格式 | 2026-08-04 |
| `flutter analyze` | 通过：No issues found | 2026-08-04 |
| `flutter test test\paper_markdown_test.dart` | 通过：17 项 Markdown/LaTeX 测试 | 2026-08-04 |
| `flutter test test\paper_ai_message_view_test.dart` | 通过：3 项 ChatPaper 可选择性测试 | 2026-08-04 |
| `flutter test` | 通过：全量 239 项测试 | 2026-08-04 |
| `flutter build apk --debug --flavor development --dart-define=PAPERFLOW_ENV=development` | 通过：`build/app/outputs/flutter-apk/app-development-debug.apk` | 2026-08-04 |
| `git diff --check` | 通过；构建生成文件无内容差异 | 2026-08-04 |

## 审查结论

审查范围：`origin/main...HEAD`，merge-base `63c00491503ad4fdad8c2f213c7d240f18a4bc1f`；3 个文件，305 行新增、61 行删除；审查日期 2026-08-04。

任务规格核对：6 项验收标准全部满足。核心布局测试验证公式、前词和逗号的 `RenderParagraph` 行框垂直重叠；块公式、选择容器、ChatPaper 不可选择和完整验证均有独立证据。

问题清单：阻断项 0，缺陷 0。建议保留当前结构/坐标回归测试，未来升级 `flutter_markdown_plus` 时优先运行，以防其文本节点合并行为变化；不阻塞本任务。

验证证据：格式检查、`flutter analyze`、全量 239 项 `flutter test`、development APK 构建和 `git diff --check` 均通过。

- 审查日期：2026-08-04
- 阻断项：无
- 缺陷：无
- 结论：可合并

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| d3fcefa | `docs: initialize inline-math-flow workstream` | `/start` 台账初始化 | `git diff --check` 通过 |
| 4756631 | `fix(markdown): keep inline formulas in paragraph flow` | `/develop` 纵向实现 | 格式、analyze、Markdown 17 项与 ChatPaper 3 项定向测试通过 |
| 03ea0f2 | `docs: record inline math implementation evidence` | `/develop` 证据记录 | 定向验证结果与决策已记录 |

## 交付记录（合并前补齐）

### 交付摘要

修复论文 Abstract 及共用 Markdown 中行内 LaTeX 被拆成独立行的问题：公式现在与前后文字共享同一个富文本段落，能够使用前文末行剩余空间并保持邻接标点连续；块公式和 ChatPaper 渲染语义保持不变。

### 实际变更

- 领域与业务逻辑：无。
- 数据与基础设施：无；未新增依赖或修改缓存/API。
- 界面与交互：`PaperLatexElementBuilder` 使用 `Text.rich + WidgetSpan(Math.tex)`；`PaperMarkdown` 通过 `SelectionArea` 保留 Abstract 文本选择，并用 `SelectionContainer.disabled` 保持不可选择场景。
- 测试与工具：新增真实 `RenderParagraph` 行框回归；更新行内/块公式断言；全量门禁通过。
- 文档：本台账记录实施、验证与审查证据；开发计划不需新增产品方向。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：只调整展示层渲染；应用未正式发布，无数据迁移负担。

### 已知风险与回滚

- 已知风险：实现依赖 `flutter_markdown_plus` 将 builder 返回的 `Text` 合并为段落；当前依赖版本和回归测试已验证，升级依赖时需重新运行布局测试。
- 回滚方式：合并后整体 revert 本任务的功能与台账提交（`4756631`、`03ea0f2`、`be290be`）；不涉及本地数据迁移。

### 文档更新建议

- 已核对 `docs/development.md`：Abstract 与 ChatPaper 已有 Markdown/公式能力描述，无需修改共享计划文档。

### 未完成与后续工作

- 无。
