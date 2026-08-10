# 任务台账

## 基本信息

- 任务：完善中文提交信息规范
- 关联发布或里程碑：无
- 分支：`docs/chinese-commit-messages`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\docs--chinese-commit-messages`
- 基线提交：`4e44858`
- 负责人：Codex
- 状态：待审查
- 最近更新：2026-08-10

## 目标

将当前过于简略且以英文为主的 commit 信息约定改为完整、可审查的中文提交信息规范，并同步相关流程文档。

## 非目标

- 不修改历史提交信息或历史台账记录。
- 不改变 Git 分支、合并和回滚策略。

## 验收标准

- [x] 规范明确中文提交主题、类型、范围、正文和验证信息的写法。
- [x] `AGENTS.md` 与流程 skill 不再要求旧的英文提交格式。
- [x] 文档格式检查通过，变更范围可解释。

## 写入范围

### 独占路径

- `AGENTS.md`
- `docs/standards/version-control.md`
- `.claude/skills/develop/SKILL.md`
- `.claude/skills/version/SKILL.md`
- `docs/workstreams/docs--chinese-commit-messages/status.md`

### 共享路径

- 无

## 实施计划

1. 完善版本控制规范中的中文 commit 格式、字段和示例。
2. 同步 AGENTS 与流程 skill 的引用和示例。
3. 执行文档检查并提交原子变更。

## 当前进度

- 已完成：创建独立分支和 worktree；定位重复规范；修改规范和流程文档；完成静态检查；提交规范变更。
- 正在进行：记录提交检查点。
- 下一步：等待编排者触发审查或合并流程。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-10 | 提交类型使用固定中文词，范围保留模块或领域名称 | 满足中文交互要求，同时保持提交结构稳定可读 | 新提交不再使用 `feat`、`fix` 等英文类型标签 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| Markdown 相关路径检查 | 通过；5 个规范引用路径存在 | 2026-08-10 |
| `git diff --check` | 通过；仅有换行符规范化提示 | 2026-08-10 |
| `git diff --cached --check` | 通过 | 2026-08-10 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `dbc6b08` | `文档（规范）：完善中文提交信息约定` | 规范实现 | Markdown 路径检查、`git diff --check` 通过 |
