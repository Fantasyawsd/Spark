---
name: finish
description: 收尾任务：整理交付信息、合并到 main、完成合并后文档归档，再清理 worktree 与分支。
disable-model-invocation: true
---

# /finish 收尾

由人类编排者在 `/review` 通过（或阻断项已解决）后、准备合并时触发。本 skill 不写新功能。

## 步骤

1. **确认可收尾**
   - 确认审查阻断项已解决或已获编排者豁免；`git status --short` 干净。
   - 完成标准：无未解决阻断项；工作区干净。

2. **整理合并前交付信息**
   - 在 status.md 补齐：交付摘要、实际变更、验证证据、兼容性与迁移、已知风险与回滚方式、审查结论。
   - 此时状态最多写“待合并”；不得写“已合并”、虚构最终集成 SHA，也不得把尚未合入的功能在 `docs/development.md` 标记为“已完成”。
   - 完成标准：合并前交付信息完整、无占位符、含回滚方式。

3. **核对合并准入**
   - 逐条核对 `AGENTS.md`「完成定义」中的合并前条件。
   - 完成标准：合并前条件全部满足；不满足项已记录并停止合并。

4. **合并**
   - 日常开发由编排者直接合并到 main（本地 merge 或 push，日常不要求 CI）；版本迭代通过 Pull Request 合并并要求 CI（`Flutter CI / verify`）通过；规则见 `docs/standards/version-control.md`「审查与合并」。
   - 完成标准：已合入 main（版本迭代时 PR 已合并）；日常不要求 CI 通过；未本地强推。

5. **在 main 完成最终归档**
   - 切换或同步控制工作树到已合并的 `main`，用 `git merge-base --is-ancestor <task-tip> main`（或已合并 PR）确认任务提交真实可达，并按风险执行集成回归。
   - 按 `docs/standards/version-control.md`「验证门禁」完成合并后双目标构建：development APK 与 Windows debug EXE 必须在同一次 `/finish` 流程中均构建成功；记录两个产物的路径、大小和 SHA-256，任一失败不得继续归档或清理。
   - 在 `main` 更新对应 status.md：状态改为“已合并”，记录最终集成 SHA 或 PR、合并时间、集成验证和真实后续项；再依据已合并能力更新 `docs/development.md`。不影响开发计划时，在台账中明确记录原因。
   - 面向发布的任务同步 `docs/releases/<version>/` 资料；将这些更新形成独立的合并后文档归档提交。若 `main` 受保护，按 `docs/standards/version-control.md` 使用仅文档 PR，归档提交合入前不得进入清理。
   - 完成标准：任务提交和合并后文档归档提交均已进入 `main`；APK 与 Windows debug EXE 构建证据完整；台账不再停留在“待合并”或“进行中”；开发计划反映真实代码状态。

6. **清理**
   - 从控制工作树执行 `git worktree remove` 与 `git worktree prune`，合并后删除分支；规则见 `docs/standards/version-control.md`「Worktree 清理」。
   - 台账 `docs/workstreams/<branch-slug>/status.md` 已完成合并后归档，继续保留且除勘误外不再更新。
   - 完成标准：worktree 已移除、分支已删或明确保留、`git worktree list` 干净。
