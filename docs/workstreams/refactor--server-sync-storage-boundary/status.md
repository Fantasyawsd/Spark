# 服务端同步存储边界任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

从 `PaperStore` 提取来源快照、同步检查点、完成水位和来源更新时间查询，使 canonical paper 在线存储不再内嵌后台同步状态持久化。

## 非目标

- 不改变 `PaperStore`、Pipeline、CLI 或端口的公开方法签名。
- 不改变快照与同步状态表结构、迁移或字段语义。
- 不移动数据集导入状态、物化索引或推荐批次持久化。
- 不进行客户端人工验收，不构建 APK/EXE，不合入 `main`。

## 分支与基线

- 分支：`refactor/server-sync-storage-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-49`
- 基线：`d8c1de4`

## 验收标准

- [x] `PaperStore` 不再内嵌快照和同步状态 SQL。
- [x] 四个同步相关公开方法保留原签名和行为。
- [x] 快照幂等覆盖、失败检查点、完成水位单调性和缺省状态保持不变。
- [x] 来源更新时间仍按来源观测的最大值解析。
- [x] 服务端全量测试、完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `server/spark_papers/sync_storage.py`
- `server/spark_papers/storage.py`
- `server/tests/test_sync_storage.py`
- `docs/workstreams/refactor--server-sync-storage-boundary/status.md`

## 实施计划

1. 提取同步状态存储组件并保留 SQL 语义。
2. 让 `PaperStore` 通过原签名委托同步持久化。
3. 补充快照、检查点、水位和更新时间直接测试。
4. 完成服务端全量、Flutter 门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 同步存储、Pipeline、CLI 与迁移定向测试 | 28 项通过；首次运行仅修正直接测试夹具使用生产迁移列 | 2026-08-14 |
| `python -m unittest discover -s server/tests -v` | 89 项通过 | 2026-08-14 |
| `python -m compileall -q server/spark_papers server/tests` | 通过 | 2026-08-14 |
| `./tool/verify_changed_dart_format.ps1 -BaseRevision d8c1de4` | 没有需要检查的 Dart 文件 | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test` | 582 项通过 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |
| 只读审查 | `PaperStore` 原四个同步方法签名保留并仅委托；快照 upsert、失败不覆盖成功时间、完成水位单调更新、缺省状态和最大来源更新时间逻辑保持；Schema/迁移、Pipeline、CLI 未修改 | 2026-08-14 |

## 审查结论

通过。`SyncStorage` 只拥有来源快照、同步状态和来源更新时间查询，未发现阻断项或行为回归。`storage.py` 从约 865 行降至 835 行。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `重构（论文服务）：拆分同步存储边界` | 实现 | 服务端 89 项、Flutter 582 项、编译和静态检查通过 |
| 待提交 | `文档（台账）：记录同步存储边界审查` | `/test` + `/review` | 记录验证与只读审查结论 |
