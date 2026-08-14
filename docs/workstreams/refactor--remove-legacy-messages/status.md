# 清理遗留 messages 模块任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

移除 `lib/src/features/messages` 中无引用的遗留消息模块，清理项目结构文档中的过时目录说明。

## 非目标

- 不修改当前 `features/chat` ChatPaper 实现。
- 不删除 README 中产品范围对 direct messages 的说明。
- 不处理其他死代码或公共导出问题。
- 不合入 `main`，不进行人工验收。

## 分支与基线

- 分支：`refactor/remove-legacy-messages`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-15`
- 基线：`8aed636713036af6ce550d6d5d685a7c5d532954`

## 验收标准

- [x] `lib/src/features/messages` 不存在。
- [x] 全库无 `MessageItem`、`demoMessages` 或遗留模块路径引用。
- [x] README 项目结构不再列出已删除目录，但产品范围说明保留。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 验证记录

| 命令 | 结果 |
| --- | --- |
| `flutter pub get` | 通过 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（检查 126 个文件） |
| `flutter analyze` | 通过 |
| `flutter test` | 通过（553 项） |
| `git diff --check` | 通过 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。删除范围仅包含无引用遗留模块及 README 结构树对应条目；当前 `features/chat` 未改动，产品范围说明保留。全库搜索与完整验证均通过。
