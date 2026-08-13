# 文件仓储持久化边界任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

收敛论文文件仓储中重复的版本化 JSON store 构造和异常映射样板，同时保留各仓储的业务读写与错误文案。

## 非目标

- 不建立跨业务模块的通用 Repository 基类。
- 不合并不同仓储的数据 shape、迁移、TTL 或更新事务。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/file-repository-persistence-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-35`
- 基线：`0fca1ea`

## 验收标准

- [x] papers/data 内有窄的版本化文件持久化边界。
- [x] 偏好、阅读、交互、评论仓储不再重复构造和 try/catch 样板。
- [x] 各仓储异常类型、错误文案、schema 和迁移保持一致。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 新增 `PaperFilePersistence`。
2. 迁移四个同构文件仓储。
3. 补充 helper 单元测试并运行完整门禁。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `flutter test test/paper_file_persistence_test.dart test/file_paper_storage_schema_test.dart test/file_paper_reading_repository_test.dart test/file_paper_comment_repository_test.dart` | 通过（18 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision 0fca1ea` | 通过（6 个文件） | 2026-08-13 |
| `flutter analyze` | 通过，无问题 | 2026-08-13 |
| `flutter test` | 通过（564 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

审查结论：阻断项 0；缺陷 0；建议 0。抽象仅覆盖 papers/data 内稳定重复的 store 构造与异常映射；schema、迁移、mapper、更新事务和中文错误文案仍由各具体仓储声明。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| e7b30f8 | 重构（论文数据）：收敛文件仓储持久化边界 | /develop | 格式、analyze、Flutter 564 项通过 |
