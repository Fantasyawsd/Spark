# PaperFlow 开发文档

> 开发文档按产品领域和工程主题持续维护；只有发布资料按版本归档。
> 每份文档的维护状态见下表（活跃：持续维护；归档：只读历史，只补勘误）。
> 最近更新：2026-08-02

## 总文档

| 文档 | 维护状态 |
| --- | --- |
| [AI Agent 开发规范](../AGENTS.md)：单人编排、skill 工作流、提交与验证约束 | 活跃 |
| [开发总路线](development-roadmap.md)：产品边界、长期能力、优先级和持续技术路线 | 活跃 |
| [代码结构原则](standards/code-structure.md)：所有开发必须遵守的架构与代码质量约束 | 活跃 |
| [Git 与任务集成管理](standards/version-control.md)：分支、worktree、提交、验证、回滚和集成规则 | 活跃 |
| [发布与兼容性管理](standards/release-management.md)：五层版本、环境渠道、数据/API 兼容和 Feature Flag 规则 | 活跃 |
| [开发技能](../.claude/skills/)：`/start`、`/develop`、`/test`、`/review`、`/finish`、`/version`、`/release`，入口见 AGENTS.md「Skill 工作流」 | 活跃 |
| [任务台账模板](templates/workstream-status.md)：单文件任务台账，skill 引用 | 活跃 |

## 产品开发文档

| 文档 | 维护状态 |
| --- | --- |
| [论文频道、索引与阅读改进](product/papers/channels-and-reading.md) | 活跃 |
| [论文开发路线](product/papers/roadmap.md) | 活跃 |
| [ChatPaper 开发路线](product/chatpaper/roadmap.md) | 活跃 |
| [我的开发路线](product/profile/roadmap.md) | 活跃 |

后续按 `product/papers/`、`product/chatpaper/`、`product/profile/` 等业务领域扩展，不按计划版本复制开发文档。

## 任务与审查

| 文档 | 维护状态 |
| --- | --- |
| [任务台账说明](workstreams/README.md)：`docs/workstreams/<slug>/status.md` 的创建与归档规则 | 活跃 |
| [2026-08 架构审查](reviews/architecture-2026-08.md) | 归档 |
| [早期论文与社区体验记录](reviews/paper-experience-history.md) | 归档 |

## 发布归档

| 版本 | 状态 | 入口 |
| --- | --- | --- |
| 0.1.0 | 功能代码候选，等待发布门 | [0.1.0 发布资料](releases/0.1.0/README.md) |

## 维护规则

1. 产品开发文档按业务领域维护唯一事实源，不为每个版本复制一份。
2. 架构、协作和 Git 规则放在 `standards/`，不混入功能计划。
3. 只有发布计划、发布检查清单、发布审计和版本隐私资料进入 `releases/<version>/`。
4. 每个任务只维护自己的 `docs/workstreams/<branch-slug>/status.md` 台账，合并后归档保留，不删除、不更新。
5. 共享总文档由编排者更新；规范变更由编排者批准。
6. 功能状态统一使用“规划中、开发中、已完成、已延期、已取消”，并说明证据或后续方向。
7. 已发布资料只补充勘误和最终证据，不用后续开发计划覆盖历史状态。
8. 一个文档一个事实源，SKILL.md 只引用规范路径、不复制规范内容；改规范一处即生效。
