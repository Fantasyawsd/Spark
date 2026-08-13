# 演示论文测试夹具边界重构任务台账

> 状态：开发中
> 最近更新：2026-08-13 21:15

## 目标

将仅供测试使用的 `DemoPaperRepository` 与 `demoPapers` 从生产 `lib/` 树迁移到 `test/support/`，避免生产包携带测试夹具。

## 非目标

- 不改变演示论文内容、测试行为或生产组合根。
- 不删除未确认的 `messages`、同步子系统或公共导出。
- 不合入 `main`，不进行人工验收。

## 分支与基线

- 分支：`refactor/demo-paper-fixture`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-14`
- 基线：`6326fbde0205d9c96948c1b01fe17ce2c9735091`

## 验收标准

- [x] `lib/` 不再包含 `demo_paper_repository.dart`。
- [x] 所有测试引用改为 `test/support/demo_paper_repository.dart`。
- [x] 夹具源码内容保持不变，引用路径可编译。
- [ ] 完整 `/test` 门禁通过。
- [ ] 只读 `/review` 通过。

## 验证记录

| 命令 | 结果 |
| --- | --- |
| 定向引用测试 | 通过，共 122 项 |
| `flutter analyze` | 通过 |
| `.\tool\verify_changed_dart_format.ps1` | 通过，126 个文件 |

## 审查结论

待审查。

## 检查点与提交

| SHA | 提交信息 | 阶段 |
| --- | --- | --- |
