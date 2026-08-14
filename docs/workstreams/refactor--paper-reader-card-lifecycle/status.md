# 收敛论文阅读卡片生命周期任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

将 `PaperReaderCard` 中翻译和关键词 controller 的创建、替换、取消与销毁逻辑提取到独立生命周期对象，降低 `didUpdateWidget` 的组合复杂度并保持行为不变。

## 非目标

- 不改变阅读卡片 UI、标签切换或派生内容缓存契约。
- 不处理其他展示组件拆分。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-reader-card-lifecycle`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-24`
- 基线：`5085b0a`

## 验收标准

- [x] `didUpdateWidget` 不再直接维护两个 controller 的构造/销毁细节。
- [x] 论文、服务或仓储变化时只替换受影响的 controller。
- [x] active 切换、取消、关键词共享缓存和全文测试保持通过。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 新增 `PaperReaderCardControllerSet`，集中管理两个派生内容 controller。
2. 接入阅读卡片并运行定向及完整门禁。
3. 完成台账审查记录并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `dart format` | 通过 | 2026-08-13 |
| `flutter test test/paper_reader_view_test.dart` | 通过（4 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（136 个文件） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter test` | 通过（554 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。controller 替换条件与原实现一致；生命周期对象集中负责监听器、取消和销毁，阅读卡片保留标签状态和异步过期检查。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
