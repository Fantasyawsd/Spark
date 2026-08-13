# 拆分 Markdown 预处理与稳定化边界任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

将 Markdown 预处理、代码围栏保护和流式语法稳定化从 `spark_markdown.dart` 独立到专用处理模块，保持现有行为和公共符号兼容。

## 非目标

- 不改变 Markdown 语法修复规则或展示样式。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/spark-markdown-processing`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-22`
- 基线：`deed2b0`

## 验收标准

- [x] 预处理、代码围栏保护和稳定化位于独立模块。
- [x] `spark_markdown.dart` 通过兼容导出保持现有测试与调用方不变。
- [x] 完整格式检查、`flutter analyze` 和 554 项测试通过。
- [x] 只读审查结论无阻断项。

## 写入范围

### 独占路径

- `lib/src/core/widgets/spark_markdown.dart`
- `lib/src/core/widgets/spark_markdown_processing.dart`
- `docs/workstreams/refactor--spark-markdown-processing/status.md`

### 共享路径

- 无。

## 实施计划

1. 提取预处理、代码围栏保护和稳定化实现。
2. 保留兼容导出，执行完整门禁。
3. 完成只读审查记录并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `dart format` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（135 个文件） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter test` | 通过（554 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。处理逻辑仅移动到专用模块，兼容导出保留；测试覆盖预处理、稳定化、代码围栏和完整渲染路径。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
