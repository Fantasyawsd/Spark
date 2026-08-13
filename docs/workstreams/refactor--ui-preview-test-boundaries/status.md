# 论文展示集成测试边界任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

将职责混杂且命名含糊的 `ui_preview_test.dart` 拆分为按阅读器、互动、目录频道和 AI 会话组织的独立集成测试套件，使失败归属和定向回归范围清晰。

## 非目标

- 不修改生产代码、用户界面或业务行为。
- 不改写断言语义、测试时序或现有 fake 的行为。
- 不新增 golden 或浏览器自动化测试。
- 不进行客户端人工验收，不构建 APK/EXE，不合入 `main`。

## 分支与基线

- 分支：`refactor/ui-preview-test-boundaries`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-44`
- 基线：`caefba9`

## 验收标准

- [x] 删除命名含糊的 `ui_preview_test.dart` 测试入口。
- [x] 原有 23 项测试按业务流程迁移到可独立运行的明确命名套件。
- [x] 共用测试 fake 位于支持目录且不包含测试断言。
- [x] 定向测试、完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `test/ui_preview_test.dart`
- `test/paper_reader_experience_test.dart`
- `test/paper_interaction_flow_test.dart`
- `test/paper_catalog_presentation_test.dart`
- `test/ai_session_navigation_test.dart`
- `test/support/paper_presentation_test_support.dart`
- `docs/workstreams/refactor--ui-preview-test-boundaries/status.md`

## 实施计划

1. 提取跨套件共享的可控服务和仓储 fake。
2. 按阅读器、互动、目录频道和 AI 会话迁移原有测试。
3. 核对测试名称与数量，运行四个新套件。
4. 完成完整门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter test test/paper_reader_experience_test.dart` | 通过，共 7 项 | 2026-08-14 |
| `flutter test test/paper_interaction_flow_test.dart` | 通过，共 9 项 | 2026-08-14 |
| `flutter test test/paper_catalog_presentation_test.dart test/ai_session_navigation_test.dart` | 通过，共 7 项 | 2026-08-14 |
| 四个新套件联合执行 | 通过，共 23 项，跨文件并发执行无状态串扰 | 2026-08-14 |
| 基线与新套件测试名称集合比较 | 通过，旧 23 项、新 23 项，差集为空 | 2026-08-14 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision caefba9`（首次） | 未通过，发现 2 个新增文件未格式化；使用项目 Dart 格式器修复 | 2026-08-14 |
| `flutter analyze`（首次） | 未通过，共享支持文件存在 1 个未使用导入；删除后复检通过 | 2026-08-14 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision caefba9`（最终） | 通过，检查 5 个 Dart 文件 | 2026-08-14 |
| `flutter analyze`（最终） | 通过，无问题 | 2026-08-14 |
| `flutter test`（最终） | 通过，共 577 项 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |

## 审查结论

只读审查通过：阻断项 0、缺陷 0、建议 0。旧入口的 23 个测试名称与四个新套件逐项一致，活跃源码和工具没有遗留 `ui_preview_test.dart` 引用；历史台账中的旧命令仅作为归档证据保留。阅读器、互动、目录频道和 AI 会话可分别定向运行；专属 fake 跟随所属套件，共享支持文件仅保留被多个套件复用的 AI 讨论与翻译装配，不含测试断言。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `11d9fb1` | `重构（测试）：拆分论文展示集成套件` | `/develop`、`/test`、`/review` | 新套件 23 项、格式检查、静态分析和全量测试 577 项均通过；测试名称集合一致；只读审查无发现 |
