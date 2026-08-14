# 拆分论文记录合并边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

将 `PaperStore` 中的字段合并逻辑提取为独立、可脱离 SQLite 测试的记录合并模块，并用 `dataclasses.replace` 消除身份迁移时的手工字段复制。

## 非目标

- 不改变身份匹配阈值、冲突入队或数据库写入事务。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-storage-merge-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-27`
- 基线：`6bf0dc8`

## 验收标准

- [x] 记录合并逻辑位于独立模块，storage 只负责持久化编排。
- [x] 身份目标变化不再手工复制 `PaperRecord` 全字段。
- [x] 跨源合并、冲突和幂等行为保持通过，并新增纯合并测试。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 新增 `paper_record_merger.py` 并迁移 `_merge`。
2. 使用 `replace` 简化目标 ID 重绑定。
3. 运行服务端与 Flutter 全量门禁，完成台账审查并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `$env:PYTHONPATH='server'; python -m unittest discover -s server/tests` | 通过（68 项） | 2026-08-13 |
| `flutter pub get` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（140 个文件） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter test` | 通过（554 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

审查结论：阻断项 0；缺陷 0；建议 0。改动范围符合目标，持久化与纯合并职责边界清晰，新增测试覆盖跨源合并、目标 ID 迁移和幂等行为。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| b191c37 | 重构（存储）：拆分论文记录合并边界 | /develop | 服务端 68 项、Flutter 554 项、analyze、格式检查通过 |
