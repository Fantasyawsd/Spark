# 服务端身份解析边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

从 `PaperStore.ingest` 提取 exact/fuzzy 身份解析策略、模糊匹配阈值和审核队列决策，使存储层聚焦查询与持久化，并让身份策略可脱离 SQLite 独立测试。

## 非目标

- 不改变外部身份标准化和模糊相似度算法。
- 不改变 SQLite schema、匹配队列字段或 `IngestOutcome` 契约。
- 不自动合并模糊候选，不调整现有 `0.65` 审核阈值。
- 不进行客户端人工验收，不构建 APK/EXE，不合入 `main`。

## 分支与基线

- 分支：`refactor/server-identity-resolution-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-43`
- 基线：`7ce7b4e`

## 验收标准

- [x] `PaperStore.ingest` 不再直接编码 exact/fuzzy 身份决策和审核阈值。
- [x] 纯 Python 身份解析模块覆盖 exact 冲突、模糊审核、未匹配和允许创建分支。
- [x] 现有管线身份合并、冲突统计和审核队列行为保持不变。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `server/spark_papers/identity_resolution.py`
- `server/spark_papers/storage.py`
- `server/tests/test_identity_resolution.py`
- `server/tests/test_pipeline.py`（仅回归验证，不计划修改）
- `docs/workstreams/refactor--server-identity-resolution-boundary/status.md`

## 实施计划

1. 提取纯身份解析结果、审核指令和模糊审核阈值。
2. 让存储层负责候选查询并执行解析结果。
3. 补充策略单元测试并运行管线身份回归。
4. 完成服务端全量测试、Flutter 门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `$env:PYTHONPATH = (Resolve-Path server).Path; python -m unittest server.tests.test_identity_resolution server.tests.test_pipeline -v` | 通过，共 20 项 | 2026-08-14 |
| `$env:PYTHONPATH = (Resolve-Path server).Path; python -m unittest discover -s server/tests -v` | 通过，共 76 项 | 2026-08-14 |
| `python -m compileall -q server/spark_papers server/tests` | 通过 | 2026-08-14 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision 7ce7b4e` | 通过，没有需要检查的 Dart 文件 | 2026-08-14 |
| `flutter analyze` | 通过，无问题 | 2026-08-14 |
| `flutter test` | 通过，共 577 项 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |

## 审查结论

只读审查通过：阻断项 0、缺陷 0、建议 0。身份解析模块不依赖 SQLite、领域模型或端口层；`PaperStore` 仅保留候选查询、审核队列写入和记录持久化。一个 exact 命中、多 exact 冲突、仅无 external ID 时 fuzzy、`0.65` 阈值边界、禁止创建时未匹配、允许创建时保留传入 ID 的行为均由独立测试覆盖，既有管线回归通过。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `fd6a888` | `重构（论文服务）：提取身份解析决策` | `/develop`、`/test`、`/review` | 定向测试 20 项、服务端全量 76 项、Python 编译检查、Flutter 静态分析和全量 577 项均通过；只读审查无发现 |
