# 批量读取 provenance 任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

将服务端论文列表读取的 provenance 查询从逐行 N+1 收敛为一次批量查询，保持论文顺序与 provenance 内容不变。

## 非目标

- 不改变数据库 schema、API 字段或 provenance 写入逻辑。
- 不优化推荐候选路径中明确不返回 provenance 的映射。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`perf/provenance-batch-read`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-19`
- 基线：`4285acb`

## 验收标准

- [x] `get` 仍返回单论文 provenance。
- [x] `list_papers`、`list_following`、`all_candidates` 使用单次 provenance 批量查询。
- [x] 论文顺序、游标和 provenance 内容保持不变，并有查询次数回归测试。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 写入范围

### 独占路径

- `server/spark_papers/storage.py`
- `server/tests/test_storage_provenance.py`
- `docs/workstreams/perf--provenance-batch-read/status.md`

### 共享路径

- 无。

## 实施计划

1. 新增 `_rows_to_papers`，按 paper_id 批量查询 provenance 并按原顺序映射。
2. 替换论文列表读取调用方，保留单篇 `get` 语义。
3. 运行服务端、Flutter 全量门禁并完成只读审查。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `$env:PYTHONPATH='server'; python -m unittest discover -s server/tests` | 通过（66 项） | 2026-08-13 |
| `flutter pub get` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（131 个文件） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter test` | 通过（553 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。批量读取仅改变 provenance 的查询次数与组装方式；`get`、列表顺序、游标及推荐路径行为保持不变。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
