# 服务端数据集存储边界任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

从 `PaperStore` 提取数据集导入租约、检查点、批量写入、拒绝记录和对账职责，使在线论文存储不再内嵌仅供 `DatasetImporter` 使用的导入状态机。

## 非目标

- 不改变 `DatasetImporter`、CLI 或 `PaperStore` 的公开方法签名。
- 不改变数据库表、字段、SQL 写入语义或每批 500 条查询分块。
- 不改变数据集映射、准入策略或进度回调。
- 不进行客户端人工验收，不构建 APK/EXE，不合入 `main`。

## 分支与基线

- 分支：`refactor/server-dataset-storage-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-47`
- 基线：`56d0b08`

## 验收标准

- [x] `PaperStore` 不再内嵌数据集租约、批次 SQL 和对账实现。
- [x] 原有数据集方法继续通过 `PaperStore` 的兼容签名调用。
- [x] 租约竞争、断点恢复、拒绝记录、增强导入和批次回滚保持不变。
- [x] 服务端全量测试、完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `server/spark_papers/database_values.py`
- `server/spark_papers/dataset_storage.py`
- `server/spark_papers/storage.py`
- `server/tests/test_dataset_storage.py`
- `docs/workstreams/refactor--server-dataset-storage-boundary/status.md`

## 实施计划

1. 提取 SQLite JSON helper 和数据集存储组件。
2. 让 `PaperStore` 通过原签名委托数据集操作。
3. 补充租约竞争、前缀查询和租约丢失回滚测试。
4. 完成服务端全量、Flutter 门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 定向服务端测试 | 22 项通过；修复误删 `timedelta` 导入和最后一处 `_json` 残留 | 2026-08-14 |
| `python -m unittest discover -s server/tests -v` | 84 项通过 | 2026-08-14 |
| `python -m compileall -q server/spark_papers server/tests` | 通过 | 2026-08-14 |
| `./tool/verify_changed_dart_format.ps1 -BaseRevision 56d0b08` | 没有需要检查的 Dart 文件 | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test` | 582 项通过 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |
| 只读审查 | `PaperStore` 原数据集方法签名保留并仅委托；`DatasetImporter`、CLI 未修改；500 条查询分块、最短 30 秒租约、事务回滚和 `fail_import` 语义保持；新增模块由 setuptools package discovery 自动纳入 | 2026-08-14 |

## 审查结论

通过。数据集导入状态机和批量写入已由 `DatasetStorage` 独立承载，在线论文存储仍负责 canonical paper、查询、索引和推荐批次；未发现行为回归或边界越界。`storage.py` 约从 1,376 行降至 921 行。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `重构（论文服务）：拆分数据集存储边界` | 实现 | 服务端 84 项、Flutter 582 项、编译和格式检查通过 |
| 待提交 | `文档（台账）：记录数据集存储边界审查` | `/test` + `/review` | 记录验证与只读审查结论 |
