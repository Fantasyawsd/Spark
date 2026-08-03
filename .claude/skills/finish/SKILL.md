---
name: finish
description: 收尾任务：完成交付记录、核对完成定义、合并到 main 并清理 worktree 与分支。
disable-model-invocation: true
---

# /finish 收尾

由人类编排者在 `/review` 通过（或阻断项已解决）后、准备合并时触发。本 skill 不写新功能。

## 步骤

1. **确认可收尾**
   - 确认审查阻断项已解决或已获编排者豁免；`git status --short` 干净。
   - 完成标准：无未解决阻断项；工作区干净。

2. **完成交付记录**
   - 在 status.md 补齐：交付摘要、实际变更、验证证据、兼容性与迁移、已知风险与回滚方式、审查结论。
   - 面向发布的任务同步 `docs/releases/<version>/` 资料；文档更新规则见 `AGENTS.md`「文档维护与分类」。
   - 完成标准：台账交付记录完整、无占位符、含回滚方式。

3. **核对完成定义**
   - 逐条核对 `AGENTS.md`「完成定义」。
   - 完成标准：全部满足；不满足项已记录并停止合并。

4. **合并**
   - 日常开发由编排者直接合并到 main（本地 merge 或 push，日常不要求 CI）；版本迭代通过 Pull Request 合并并要求 CI（`Flutter CI / verify`）通过；规则见 `docs/standards/version-control.md`「审查与集成」。
   - 完成标准：已合入 main（版本迭代时 PR 已合并）；日常不要求 CI 通过；未本地强推。

5. **清理**
   - 从控制工作树执行 `git worktree remove` 与 `git worktree prune`，合并后删除分支；规则见 `docs/standards/version-control.md`「Worktree 清理」。
   - 台账 `docs/workstreams/<branch-slug>/status.md` 归档保留，不删除、不更新。
   - 完成标准：worktree 已移除、分支已删或明确保留、`git worktree list` 干净。
