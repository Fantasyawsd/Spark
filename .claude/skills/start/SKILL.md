---
name: start
description: 启动新开发任务：确认目标与验收、读取必读文档、创建分支与 worktree、初始化任务台账。
disable-model-invocation: true
---

# /start 启动任务

由人类编排者在新需求开始时手动触发。只做环境搭建与计划，不写功能代码。

## 步骤

1. **确认任务边界**
   - 与编排者确认：目标、优先级、验收标准、是否关联某次发布。
   - 完成标准：目标是一句可验证的业务结果；验收标准可观察、可测量；是否关联发布已明确。

2. **读取开发前必读**
   - 按 `AGENTS.md`「开发前必读」列出的顺序读取：`README.md`、`docs/README.md`、`docs/development.md`、`docs/standards/` 三份规范、可能重叠的 `docs/workstreams/<slug>/status.md`。
   - 完成标准：全部必读已读；对任务边界与约束有结论；未依据过时路径。

3. **确认基线**
   - 运行 `git status --short`、`git diff --stat`、`git log -5 --oneline`、`git worktree list`；创建前检查见 `docs/standards/version-control.md`「Worktree 隔离」。
   - 完成标准：工作区干净或改动归属明确；批准基线已确认（默认 `origin/main`）。

4. **创建分支与 worktree**
   - 执行 `git worktree add ..\PaperFlow-worktrees\<branch-slug> -b <type>/<slug> <approved-base>`。
   - 分支格式 `<type>/<slug>`（feature/fix/refactor/test/docs）与 worktree 约束见 `AGENTS.md`「分支与 worktree」。
   - 完成标准：worktree 已创建且当前分支匹配；路径位于仓库外；未使用 `git reset --hard`、`git clean` 或强制 checkout。

5. **初始化任务台账**
   - 从 `docs/templates/workstream-status.md` 创建 `docs/workstreams/<slug>/status.md`（slug 为分支名中 `/` 替换为 `--`），填入目标、非目标、验收标准、实施计划与基线 SHA。
   - 完成标准：status.md 存在且无占位符；记录分支、worktree、基线提交。

## 完成后

向编排者报告：任务目标、分支、worktree 路径、基线 SHA。等待编排者触发 `/develop`。
