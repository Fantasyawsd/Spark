# 拆分 PDF 提取分块流水线任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

将 PDF 文本分块算法从 `PaperPdfExtractionService` 提取到独立纯模块，并把 `PaperPdfException` 放入领域契约，降低下载、worker 编排和算法混杂程度。

## 非目标

- 不改变下载限制、isolate 协议、缓存版本或提取结果格式。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-pdf-extraction-pipeline`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-26`
- 基线：`7d9b13c`

## 验收标准

- [x] 分块算法位于独立数据模块，服务类仅负责下载/worker 编排。
- [x] `PaperPdfException` 由领域契约提供，现有调用方兼容。
- [x] PDF 提取、限制、超时和缓存测试保持通过。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 提取 `paper_pdf_chunker.dart`，迁移分块和段落切分逻辑。
2. 将异常类型移入领域层并接回服务。
3. 运行完整门禁，完成台账审查并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `dart format` | 通过 | 2026-08-13 |
| `flutter test test/paper_pdf_test.dart` | 通过（21 项） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（140 个文件） | 2026-08-13 |
| `flutter test` | 通过（554 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。分块算法逐行迁移到纯模块；页面标签、字符/块上限和断句规则保持一致，下载和 worker 协议未改动。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
