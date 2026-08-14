# 拆分 Markdown LaTeX 渲染边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

将 Markdown LaTeX 语法解析与 Widget 构建从 `spark_markdown.dart` 独立到专用模块，保持现有渲染行为和公共符号兼容。

## 非目标

- 不改变 Markdown 预处理、流式稳定化或主题样式行为。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/spark-markdown-pipeline`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-21`
- 基线：`b09f51f`

## 验收标准

- [x] LaTeX 解析和 Widget 构建位于独立模块。
- [x] `spark_markdown.dart` 通过兼容导出保持现有测试与调用方不变。
- [x] LaTeX、预处理和渲染测试全部通过。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 写入范围

### 独占路径

- `lib/src/core/widgets/spark_markdown.dart`
- `lib/src/core/widgets/spark_markdown_latex.dart`
- `docs/workstreams/refactor--spark-markdown-pipeline/status.md`

### 共享路径

- 无。

## 实施计划

1. 提取 `SparkLatexInlineSyntax` 与 `SparkLatexElementBuilder`。
2. 保留兼容导出，运行定向和完整门禁。
3. 完成只读审查记录并提交。

## 当前进度

- 已完成：LaTeX 解析与构建类提取；定向 Markdown 测试 30 项通过。
- 正在进行：执行完整验证门禁。
- 下一步：提交修复并基于新基线继续处理预处理/稳定化拆分。
- 阻塞项：无。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `dart format` | 通过 | 2026-08-13 |
| `flutter test test/spark_markdown_test.dart` | 通过（30 项） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter pub get` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（134 个文件） | 2026-08-13 |
| `flutter test` | 通过（554 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。LaTeX 解析与 Widget 构建仅移动到专用模块，`spark_markdown.dart` 保留兼容导出，未改变预处理、样式或渲染行为。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
