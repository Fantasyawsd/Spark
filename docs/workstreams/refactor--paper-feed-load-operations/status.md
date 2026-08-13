# 收敛论文目录加载流程任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

合并 `PaperFeedController` 中刷新与分页加载的重复异步编排，保持并发、错误、过期请求和加载状态行为不变。

## 非目标

- 不改变目录查询参数、缓存策略或分页合并规则。
- 不处理其他大文件拆分。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-feed-load-operations`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-18`
- 基线：`f021b10`

## 验收标准

- [x] 刷新与加载更多共用一个请求执行路径。
- [x] 刷新/分页各自的加载状态、诊断操作名和错误提示保持原语义。
- [x] 过期请求不会覆盖当前频道，现有分页与刷新测试保持通过。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 写入范围

### 独占路径

- `lib/src/features/papers/application/paper_feed_controller.dart`
- `docs/workstreams/refactor--paper-feed-load-operations/status.md`

### 共享路径

- 无。

## 实施计划

1. 将刷新和分页的请求执行、错误处理、状态收尾合并为共享私有方法。
2. 运行定向测试与完整门禁，检查生成文件噪声。
3. 完成只读审查记录并提交。

## 当前进度

- 已完成：共享请求路径实现；定向 `paper_controller_test.dart` 与 `paper_api_controller_query_test.dart` 40 项通过。
- 正在进行：执行完整验证门禁。
- 下一步：记录审查结论并提交。
- 阻塞项：无。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `dart format ...` | 通过 | 2026-08-13 |
| `flutter test test/paper_controller_test.dart test/paper_api_controller_query_test.dart` | 通过（40 项） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter test` | 通过（553 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（131 个文件） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。共享方法仅收敛请求执行和收尾逻辑；刷新、分页状态字段、诊断操作名、错误文案及过期请求保护均保留。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
