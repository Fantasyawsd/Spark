# 论文关键词文件仓储测试任务台账

> 状态：开发中
> 最近更新：2026-08-13 20:59

## 1. 任务信息

| 项目 | 内容 |
| --- | --- |
| 目标 | 为 `FilePaperKeywordRepository` 补齐真实文件行为测试，锁定版本化存储、记录往返、清除、损坏隔离和并发保存契约。 |
| 非目标 | 不修改生产仓储、缓存策略或 schema；不处理安全凭据仓储和其他报告问题；不合入 `main`，不进行人工桌面验收。 |
| 分支 | `test/file-paper-keyword-repository` |
| worktree | `C:\Users\Fantasy\Desktop\Spark-worktrees\agent-12` |
| 基线 | `581c8f3231fb8efd71e3eef95ab08aae4e260370`（上一批 `refactor/paper-content-fingerprint` 最终审查提交） |
| 负责人 | Fantasy（编排）；Codex（执行） |
| 当前阶段 | `/develop` |

## 2. 验收标准

1. 测试使用 `Directory.systemTemp` 和真实 `LocalJsonStore` 文件，不用 mock 文件系统。
2. 保存/读取完整保留关键词、fingerprint、prompt version 和 UTC `generatedAt`。
3. 文件 envelope 使用 `papers.keywords` schema，清除单条记录不影响其他论文。
4. 非法记录触发 `PaperKeywordPersistenceException` 并由版本化存储隔离损坏文件。
5. 两个仓储实例并发保存不会互相覆盖。
6. 定向测试、`flutter analyze`、格式门禁和 `/test` 全量门禁全部通过。

## 3. 写入范围

- `test/file_paper_keyword_repository_test.dart`
- 本台账

## 4. 实施计划

1. 增加真实文件 roundtrip、envelope、清除、损坏和并发测试。
2. 运行定向测试、analyze、格式门禁并形成原子测试提交。
3. 执行 `/test` 与 `/review`，记录最终串行基线。

## 5. 当前进度

- 已完成：确认该仓储仍无直接行为测试，报告测试缺口成立。
- 已完成：真实文件 roundtrip、版本化 envelope、单条清除、损坏隔离和并发保存测试已通过。
- 正在进行：形成 `/develop` 原子测试提交。
- 下一步：执行完整 `/test`，再进入只读 `/review`。
- 阻塞项：无。

## 6. 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 新建独立测试文件，不继续扩张综合 schema 测试。 | 仓储的并发与清除行为属于独立契约，便于定位失败。 | 生产代码无变化。 |

## 7. 验证记录

| 时间 | 阶段 | 命令或检查 | 结果 |
| --- | --- | --- | --- |
| 2026-08-13 20:59 | `/develop` | `flutter test test\file_paper_keyword_repository_test.dart test\file_paper_storage_schema_test.dart` | 通过，共 14 项；新增 4 项真实文件仓储契约。 |
| 2026-08-13 20:59 | `/develop` | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 20:59 | `/develop` | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 118 个变更相关 Dart 文件。 |
| 2026-08-13 20:59 | `/develop` | `git diff --check` | 通过。 |

## 8. 审查与交付

- 审查范围：待填写。
- 阻断项：待审查。
- 缺陷：待审查。
- 审查结论：待审查。
- 兼容性：无生产行为变化。
- 回滚：回滚测试与台账提交，不触碰 `main`。

## 9. 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
