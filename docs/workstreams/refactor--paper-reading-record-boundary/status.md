# 论文阅读状态记录边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

为论文阅读状态建立独立的 data Record，使 JSON 映射不再直接序列化领域快照，并保持 `PaperReadingRepository` 契约和本地 JSON schema 兼容。

## 非目标

- 不调整阅读状态的业务语义、历史上限或写队列。
- 不迁移或清除现有阅读状态文件。
- 不修改 Controller 的状态机和用户可见行为。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-reading-record-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-39`
- 基线：`f59e890`

## 验收标准

- [x] JSON Mapper 只接收和返回 data 层阅读状态 Record。
- [x] 文件仓储显式完成领域快照与 Record 的双向转换。
- [x] 现有阅读状态 JSON 字段、schema 版本和行为保持不变。
- [x] 映射边界具备定向测试，完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `lib/src/features/papers/data/paper_reading_record.dart`
- `lib/src/features/papers/data/paper_reading_json_mapper.dart`
- `lib/src/features/papers/data/file_paper_reading_repository.dart`
- `test/paper_reading_record_boundary_test.dart`
- `docs/workstreams/refactor--paper-reading-record-boundary/status.md`

## 实施计划

1. 新增阅读状态 Record 及领域转换。
2. 调整 Mapper 和文件仓储，使序列化停留在 data 层。
3. 新增边界测试并运行定向与完整验证门禁。
4. 完成只读审查，分别提交代码和台账。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `flutter test test/paper_reading_record_boundary_test.dart test/file_paper_reading_repository_test.dart test/paper_reading_controller_test.dart` | 通过，共 8 项 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision f59e890` | 通过，检查 4 个 Dart 文件 | 2026-08-13 |
| `flutter analyze` | 通过，无问题 | 2026-08-13 |
| `flutter test` | 通过，共 571 项 | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查通过：阻断项 0、缺陷 0、建议 0。Mapper 的领域导入已移除，文件仓储是领域快照与持久化 Record 的唯一转换点；JSON 字段和 schema 版本未变化。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `dde3ccc` | `重构（论文）：分离阅读状态记录` | `/develop`、`/test`、`/review` | 定向测试 8 项、格式检查、静态分析和全量测试 571 项均通过；只读审查无发现 |
