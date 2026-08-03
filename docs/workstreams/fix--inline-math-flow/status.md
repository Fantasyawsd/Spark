# 任务台账

## 基本信息

- 任务：修复论文摘要中的行内公式断行
- 关联发布或里程碑：不关联发布（日常缺陷修复）
- 分支：`fix/inline-math-flow`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\fix--inline-math-flow`
- 基线提交：`63c00491503ad4fdad8c2f213c7d240f18a4bc1f`（`origin/main`）
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：开发中
- 最近更新：2026-08-04 03:30

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
- [ ] 格式检查、`flutter analyze`、全量 `flutter test` 和 development APK 构建通过。

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
- 正在进行：`/develop` 已完成，准备执行 `/test` 完整验证门禁。
- 下一步：运行格式、analyze、全量测试与 development APK 构建并记录结果。
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

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：待审查
- 阻断项：待审查
- 缺陷：待审查
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| d3fcefa | `docs: initialize inline-math-flow workstream` | `/start` 台账初始化 | `git diff --check` 通过 |
| 4756631 | `fix(markdown): keep inline formulas in paragraph flow` | `/develop` 纵向实现 | 格式、analyze、Markdown 17 项与 ChatPaper 3 项定向测试通过 |

## 交付记录（合并前补齐）

### 交付摘要

待 `/finish` 根据实际实现补齐。

### 实际变更

- 领域与业务逻辑：无，待最终核对。
- 数据与基础设施：无，待最终核对。
- 界面与交互：待实现真正的行内公式排版。
- 测试与工具：待补充布局回归测试。
- 文档：任务台账已初始化；开发计划待 `/finish` 核对。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：只调整展示层渲染，待最终验证。

### 已知风险与回滚

- 已知风险：行内 Widget 与文本选择的 Flutter 支持边界、复杂 Markdown 内联样式和流式未闭合公式需回归验证。
- 回滚方式：任务合并后可整体 `git revert` 本任务提交；不涉及本地数据迁移。

### 文档更新建议

- `/finish` 时核对 `docs/development.md` 中 Abstract 与 ChatPaper 的公式渲染能力描述，只更新已验证事实。

### 未完成与后续工作

- 当前为开发中；最终交付前不得保留未完成项。
