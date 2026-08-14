# 服务端索引存储边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

从 `PaperStore` 提取物化论文索引的刷新与就绪判定，使 canonical paper 在线读写不再内嵌索引生命周期实现。

## 非目标

- 不改变 `PaperStore`、Pipeline、CLI 或端口的公开方法签名。
- 不改变索引表结构、候选池规则、年龄桶边界、排序规则或每池 5000 条上限。
- 不移动推荐查询、外部增强候选查询或同步状态持久化。
- 不进行客户端人工验收，不构建 APK/EXE，不合入 `main`。

## 分支与基线

- 分支：`refactor/server-index-storage-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-48`
- 基线：`6d9bb4d`

## 验收标准

- [x] `PaperStore` 不再内嵌索引刷新 SQL 和就绪统计实现。
- [x] `refresh_indexes()` 与 `indexes_ready()` 保留原签名和行为。
- [x] 最新、频道、作者、会议和候选池索引内容保持不变。
- [x] 三段事务提交及候选池失败回滚语义有独立测试保护。
- [x] 服务端全量测试、完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `server/spark_papers/index_storage.py`
- `server/spark_papers/storage.py`
- `server/tests/test_index_storage.py`
- `docs/workstreams/refactor--server-index-storage-boundary/status.md`

## 实施计划

1. 提取索引存储组件并保留原事务边界。
2. 让 `PaperStore` 通过原签名委托索引生命周期。
3. 补充索引内容、就绪判定和失败回滚测试。
4. 完成服务端全量、Flutter 门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 索引、推荐、Pipeline 与 CLI 定向测试 | 29 项通过；首次运行仅修正 `sqlite3.Row` 测试断言，不涉及生产实现 | 2026-08-14 |
| `python -m unittest discover -s server/tests -v` | 86 项通过 | 2026-08-14 |
| `python -m compileall -q server/spark_papers server/tests` | 通过 | 2026-08-14 |
| `./tool/verify_changed_dart_format.ps1 -BaseRevision 6d9bb4d` | 没有需要检查的 Dart 文件 | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test` | 582 项通过 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |
| 只读审查 | Pipeline、CLI 和端口未修改；原三段事务提交、年龄桶、池名称、排序、5000 条上限和就绪判定条件逐项保留；候选池失败时已提交索引更新、旧候选池保留的语义有直接测试 | 2026-08-14 |

## 审查结论

通过。`IndexStorage` 只拥有物化索引刷新与就绪判定，`PaperStore` 保留兼容委托；未发现阻断项或行为回归。`storage.py` 从约 970 行降至 865 行。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `重构（论文服务）：拆分索引存储边界` | 实现 | 服务端 86 项、Flutter 582 项、编译和静态检查通过 |
| 待提交 | `文档（台账）：记录索引存储边界审查` | `/test` + `/review` | 记录验证与只读审查结论 |
