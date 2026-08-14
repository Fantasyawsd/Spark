# 文档与代码一致性修复台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

修复全面审计发现的文档与代码不一致（8 处），使文档重新对齐代码与 git 事实：

1. 版本与发布状态过时：`AGENTS.md`、`docs/standards/release-management.md`、`docs/development.md` 声明 `0.0.1+1`/未发布，实际为 `0.1.0+2`、已发布 v0.1.0（GitHub Release）。
2. 规范矛盾：分支命名（`release-management.md` 用 `<agent>/<type>-<slug>`，其余用 `<type>/<slug>`）；构建命令（门禁要求 release/profile，`release-management.md` 示例与 CI 用 debug）。
3. 六页阅读器第 5 页签文档写「AI 解读」，UI 实际为「论文解读」。
4. `development.md` §4.1 会议频道名单（23 个）与代码 `PaperConferenceCatalog`（19 个）不符。
5. README 结构树遗漏 `server/`；中文 README 仍列已清空的 `messages/` 模块。
6. `docs/workstreams/README.md` 标题残留旧项目名 PaperFlow。
7. 51 个任务台账停留在合并前状态（待合并/待审查/开发中等），对应提交实际均已进入 `main`。
8. `docs/README.md` 索引「最近更新」日期滞后。

## 非目标

- 不修改任何代码实现；所有修复均为文档侧事实对齐。
- 不修改已归档发布资料 `docs/releases/0.1.0/`。
- 不改动 CI 配置（`ci.yml` 的 debug 构建角色由规范说明，不在本任务内改动基础设施）。
- 不修改历史台账中的既有记录内容，只更新状态行并补充合并归档信息。
- 不动 §3.1 数据侧数字（数据库内容，无法从仓库验证）。

## 分支与基线

- 分支：`fix/doc-code-drift`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`ba6c879`
- 负责人：Fantasy（编排者批准）；执行：DeepSeek Agent

## 验收标准

- [x] 三处版本/发布状态声明与实际一致（0.1.0+2、v0.1.0 已发布、发布归档存在）。
- [x] 分支命名与构建命令在三份规范文档（AGENTS.md、version-control.md、release-management.md）中一致。
- [x] 页签文案与代码一致（「论文解读」）。
- [x] 会议频道名单与 `PaperConferenceCatalog` 的 19 个一致。
- [x] README（中英）结构树包含 `server/`，中文版移除空模块 `messages/`。
- [x] 51 个台账状态更新为「已合并」并补充合并归档信息。
- [x] `git diff --check` 通过；Markdown 链接检查通过。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `git diff --check` | 通过，无空白错误 | 2026-08-14 |
| Markdown 链接检查（8 个改动文档的相对链接） | 0 断链 | 2026-08-14 |
| 台账行尾抽查（`git ls-files --eol`） | 全部 `i/lf w/crlf`，与仓库既有文件一致 | 2026-08-14 |
| 51 个台账状态与归档行抽查（3 个样本） | 格式正确，无意外内容变化 | 2026-08-14 |
| 主文档 diff 逐项审查（7 个文件） | 仅预期行变化，无顺带改动 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `b8f1e2b` | `文档（规范）：同步版本发布状态并统一分支与构建规则` | 实现 | AGENTS.md、release-management.md |
| `a34e850` | `文档（产品）：对齐阅读页签、会议频道与发布状态` | 实现 | development.md |
| `af70ec9` | `文档（结构）：README 结构树补充服务端与页签文案` | 实现 | README.md、README.zh-CN.md |
| `9da5471` | `文档（杂项）：清理 PaperFlow 品牌残留` | 实现 | workstreams/README.md |
| `2eb9c29` | `文档（归档）：补记审计批次台账合并状态` | 实现 | 51 个 status.md |
| `984098d` | `文档（索引）：更新文档索引日期并归档本任务台账` | 实现 | docs/README.md、fix--doc-code-drift/status.md |

## 审查结论

只读审查通过。6 个提交每个只表达一个意图：规范（版本/发布/分支/构建）、产品文档、README 结构、品牌残留、台账归档、索引。全部 diff 仅包含预期行变化；`git diff --check` 与 Markdown 链接检查通过；行尾与仓库既有约定一致（索引 LF、工作区 CRLF）。无阻断项。

## 合并前交付信息

- 交付摘要：修复审计发现的 8 类文档与代码不一致，共 59 个文件（7 个活跃文档 + 51 个历史台账 + 本任务台账），见检查点与提交（7 个提交）。
- 兼容性与迁移：纯文档任务，无数据 schema、接口契约或兼容性影响，不涉及迁移。
- 已知风险与回滚：无运行时风险；提交按主题分组，可逐提交 `git revert` 独立回退。
- 集成验证（合并后）：`git diff --check`、Markdown 链接检查；本任务为纯文档任务，按 AGENTS.md §10 不执行无意义的 Flutter 双目标构建。
