# 关键词领域与存储记录边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

将 `PaperKeywordRecord` 拆分为领域侧的关键词缓存实体与 data 侧的 JSON 存储记录，避免同一类型同时承担业务契约、仓储返回值和持久化模型。

## 非目标

- 不改变关键词生成、版本新鲜度判断、缓存键或用户可见行为。
- 不处理评论、交互快照等其他记录类型。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-keyword-record-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-32`
- 基线：`bc845cf`

## 验收标准

- [x] 领域层不再暴露名为 `Record` 的 JSON 存储模型。
- [x] mapper 明确负责 `PaperKeywordCacheRecord` 与领域实体之间的转换。
- [x] 关键词控制器、上下文加载器和仓储行为保持通过。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 新增领域 `PaperKeywordCache` 与 data `PaperKeywordCacheRecord`。
2. 调整仓储接口、mapper、文件/内存实现和应用层调用。
3. 更新测试、运行完整门禁并完成只读审查。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `flutter analyze` | 通过，无问题 | 2026-08-13 |
| `flutter test test/file_paper_keyword_repository_test.dart test/paper_keyword_test.dart test/paper_chat_context_loader_test.dart test/paper_reader_view_test.dart test/architecture_boundaries_test.dart` | 通过（33 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision bc845cf` | 通过（14 个文件） | 2026-08-13 |
| `flutter test` | 通过（562 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

审查结论：阻断项 0；缺陷 0；建议 0。领域接口仅暴露 `PaperKeywordCache`，JSON mapper 和文件仓储在 data 层完成 `PaperKeywordCacheRecord` 转换，应用层不依赖存储记录类型。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 9022db4 | 重构（论文数据）：分离关键词缓存记录边界 | /develop | 格式、analyze、Flutter 562 项通过 |
