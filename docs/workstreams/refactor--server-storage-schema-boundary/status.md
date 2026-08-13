# 服务端存储 Schema 边界任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

从 `PaperStore` 提取 SQLite 建表、兼容标记、数据库版本校验和迁移执行职责，使运行时存储聚焦论文查询、写入和导入，并让 schema 生命周期可独立测试。

## 非目标

- 不修改表、索引、schema 标记或 SQL 迁移内容。
- 不调整 schema 初始化与迁移的执行顺序。
- 不改变 `PaperStore` 公共 API、数据库路径或连接配置。
- 不进行客户端人工验收，不构建 APK/EXE，不合入 `main`。

## 分支与基线

- 分支：`refactor/server-storage-schema-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-45`
- 基线：`645e6b1`

## 验收标准

- [x] `PaperStore` 不再内嵌建表 SQL 和迁移文件编排。
- [x] schema 管理器可通过注入迁移目录脱离 `PaperStore` 测试。
- [x] 旧数据库升级、未来版本拒绝和 wheel 内迁移行为保持不变。
- [x] 服务端全量测试、完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `server/spark_papers/storage.py`
- `server/spark_papers/storage_schema.py`
- `server/tests/test_storage_schema.py`
- `docs/workstreams/refactor--server-storage-schema-boundary/status.md`

## 实施计划

1. 提取 schema 创建、兼容标记和迁移生命周期管理器。
2. 让 `PaperStore` 构造器委托 schema 初始化。
3. 补充迁移目录、版本上限和事务失败单元测试。
4. 完成服务端全量、Flutter 门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `$env:PYTHONPATH = (Resolve-Path server).Path; python -m unittest server.tests.test_storage_schema server.tests.test_storage_migrations server.tests.test_pipeline -v` | 通过，共 21 项 | 2026-08-14 |
| `$env:PYTHONPATH = (Resolve-Path server).Path; python -m unittest discover -s server/tests -v` | 通过，共 82 项 | 2026-08-14 |
| `python -m compileall -q server/spark_papers server/tests` | 通过 | 2026-08-14 |
| Python AST 比较提取前后的 `executescript` SQL 常量 | 通过，建表 SQL 7848 字符逐字一致 | 2026-08-14 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision 645e6b1` | 通过，没有需要检查的 Dart 文件 | 2026-08-14 |
| `flutter analyze` | 通过，无问题 | 2026-08-14 |
| `flutter test` | 通过，共 577 项 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |

## 审查结论

只读审查通过：阻断项 0、缺陷 0、建议 0。`PaperStore` 构造器仍按“版本上限检查 → 建表与兼容标记提交 → SQL 迁移”顺序初始化，初始化异常仍关闭连接。独立测试覆盖空库初始化、顺序迁移与幂等、非法文件名、非连续版本、未来版本拒绝和失败迁移回滚；既有 wheel 测试证明新 Python 模块和迁移 SQL 均进入安装包。建表 SQL 与基线逐字一致，`storage.py` 从约 1519 行降至 1246 行。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `b033a56` | `重构（论文服务）：拆分存储 Schema 生命周期` | `/develop`、`/test`、`/review` | 定向测试 21 项、服务端全量 82 项、Python 编译、SQL 等值检查、Flutter 静态分析和全量 577 项均通过；只读审查无发现 |
