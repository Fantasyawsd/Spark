# 论文导航测试拆分任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

将 `ui_preview_test.dart` 中独立的论文导航流程迁移到明确命名的测试文件，降低单文件规模和职责混杂。

## 非目标

- 不改变生产导航行为或测试断言语义。
- 不拆分评论、翻译、Feed 布局和 AI 会话测试。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-navigation-tests`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-36`
- 基线：`6f76124`

## 验收标准

- [x] 相关论文、收藏详情、底栏刷新和搜索详情导航测试有独立文件。
- [x] 原 `ui_preview_test.dart` 不再包含上述导航流程和专属 fake。
- [x] 拆分前后的测试断言与总测试行为保持一致。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 新增 `paper_navigation_flow_test.dart`。
2. 迁移四条导航流和专属 catalog fake。
3. 运行完整门禁，完成只读审查并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `flutter test test/paper_navigation_flow_test.dart test/ui_preview_test.dart` | 通过（28 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision 6f76124` | 通过（2 个文件） | 2026-08-13 |
| `flutter analyze` | 通过，无问题 | 2026-08-13 |
| `flutter test` | 通过（564 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |
| `ui_preview_test.dart` 行数 | 由 1508 行降至 1268 行 | 2026-08-13 |

## 审查结论

审查结论：阻断项 0；缺陷 0；建议 0。迁移仅移动四条导航流程及一个专属 catalog fake，断言、依赖和测试数量保持一致；生产代码未修改。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 4f9e087 | 重构（测试）：拆分论文导航流程 | /develop | 格式、analyze、Flutter 564 项通过 |
