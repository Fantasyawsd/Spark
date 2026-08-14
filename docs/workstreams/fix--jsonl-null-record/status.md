# 拒绝损坏 JSONL 记录任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

让遗留 `JsonLinesFileSource` 对 `null`、标量和非法 JSON 行显式失败并报告行号，避免损坏记录被静默过滤或逃逸为通用异常。

## 非目标

- 不改变生产 `DatasetImporter` 已有的 `Mapping` 校验逻辑。
- 不改变合法 JSON 对象的读取契约。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`fix/jsonl-null-record`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-23`
- 基线：`369e812`

## 验收标准

- [x] JSONL 中的 `null`/标量行抛出 `SourceError`。
- [x] 非法 JSON 行抛出带行号的 `SourceError`。
- [x] 合法对象读取行为保持不变，并有回归测试。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 为 JSONL 逐行解析增加异常封装和对象类型校验。
2. 增加损坏行回归测试，运行服务端与 Flutter 全量门禁。
3. 完成台账审查记录并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `$env:PYTHONPATH='server'; python -m unittest discover -s server/tests` | 通过（67 项） | 2026-08-13 |
| `flutter pub get` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（135 个文件） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter test` | 通过（554 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。JSONL 读取现在拒绝非对象和非法 JSON，并保留行号；合法对象路径与原有快照契约不变。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
