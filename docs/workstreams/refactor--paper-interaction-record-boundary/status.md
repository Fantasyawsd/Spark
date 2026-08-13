# 交互快照与存储记录边界任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

将论文交互 JSON mapper 使用的持久化记录从领域 `PaperInteractionSnapshot` 中分离，明确 data 层记录与领域快照之间的转换边界。

## 非目标

- 不改变收藏分组、点赞、关注和分享计数的领域归一化规则。
- 不改变仓储接口和 Controller 状态机。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-interaction-record-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-33`
- 基线：`77606a3`

## 验收标准

- [x] JSON mapper 只负责 `PaperInteractionRecord` 与 JSON 的转换。
- [x] 文件仓储显式完成 Record 与领域 Snapshot 的转换。
- [x] 交互领域归一化、迁移和仓储测试保持通过。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 新增 data 层 `PaperInteractionRecord`。
2. 调整 mapper 和文件仓储转换。
3. 运行完整门禁，完成只读审查并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `flutter test test/paper_interaction_controller_test.dart test/file_paper_storage_schema_test.dart test/paper_follow_state_source_test.dart` | 通过（25 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision 77606a3` | 通过（3 个文件） | 2026-08-13 |
| `flutter analyze` | 通过，无问题 | 2026-08-13 |
| `flutter test` | 通过（562 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

审查结论：阻断项 0；缺陷 0；建议 0。JSON mapper 只接触 data Record，文件仓储负责领域转换；旧 schema 的 `savedPaperIds` 仍在 Record 层兼容并由领域构造器归并到默认收藏组。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 3c76eae | 重构（论文数据）：分离交互存储记录边界 | /develop | 格式、analyze、Flutter 562 项通过 |
