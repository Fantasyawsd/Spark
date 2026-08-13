# 评论领域与存储记录边界任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

将领域 `PaperCommentRecord` 重命名为 `PaperComment`，并在 data 层引入真正的 `PaperCommentRecord`，避免同一类型同时承担领域评论和 JSON 存储记录。

## 非目标

- 不改变评论、回复、点赞和本地用户语义。
- 不改变仓储异常、JSON schema 或 UI 展示。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-comment-record-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-34`
- 基线：`d806ab0`

## 验收标准

- [x] 领域和应用层使用 `PaperComment`，不再暴露存储 Record。
- [x] JSON mapper 只处理 data 层 `PaperCommentRecord`。
- [x] 文件仓储明确转换 Record 与领域评论。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 提取领域 `PaperComment` 并调整仓储契约。
2. 新增 data Record，调整 mapper 和文件仓储转换。
3. 更新测试，运行完整门禁并完成只读审查。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `flutter test test/file_paper_comment_repository_test.dart test/paper_comment_controller_test.dart test/ui_preview_test.dart` | 通过（37 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision d806ab0` | 通过（11 个文件） | 2026-08-13 |
| `flutter analyze` | 通过，无问题 | 2026-08-13 |
| `flutter test` | 通过（562 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

审查结论：阻断项 0；缺陷 0；建议 0。领域、应用和公开 API 使用 `PaperComment`；data Record 仅在 mapper/文件仓储中出现，转换保留全部评论字段和既有 JSON schema。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| f2c6254 | 重构（论文数据）：分离评论存储记录边界 | /develop | 格式、analyze、Flutter 562 项通过 |
