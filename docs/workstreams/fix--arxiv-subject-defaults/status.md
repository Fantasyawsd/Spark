# 统一 arXiv 默认分类任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

让 Feed、Atom 客户端和 JSONL 导入器统一复用领域层 arXiv 分类目录，消除默认分类集合漂移。

## 非目标

- 不改变用户自定义频道分类和显式 `targetCategories` 覆盖行为。
- 不扩大到非 `cs.*` 的跨学科分类。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`fix/arxiv-subject-defaults`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-17`
- 基线：`7bdadb5`

## 验收标准

- [x] Feed 默认查询使用权威目录中的全部 `cs.*` 分类。
- [x] Atom 客户端默认查询与 Feed 使用同一分类集合。
- [x] JSONL 导入器默认目标分类与权威目录一致，显式覆盖仍可用。
- [x] 旧分类断言更新为契约测试，格式、analyze 和全量测试通过。

## 写入范围

### 独占路径

- `lib/src/features/papers/domain/arxiv_subject_catalog.dart`
- `lib/src/features/papers/application/paper_feed_controller.dart`
- `lib/src/features/papers/data/arxiv_jsonl_importer.dart`
- `lib/src/features/papers/data/providers/arxiv/arxiv_atom_client.dart`
- `test/arxiv_atom_client_test.dart`
- `test/paper_controller_test.dart`
- `test/paper_sources_test.dart`
- `docs/workstreams/fix--arxiv-subject-defaults/status.md`

### 共享路径

- 无。

## 实施计划

1. 暴露领域目录代码列表，替换三个默认集合。
2. 更新受影响测试并运行完整门禁。
3. 完成只读审查记录并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（131 个文件） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter test` | 通过（553 项） | 2026-08-13 |
| `git diff --check` | 待提交前复核 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。默认分类仅由领域目录提供，测试覆盖 Feed/Atom/JSONL 三个调用方；未修改显式分类参数语义。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
