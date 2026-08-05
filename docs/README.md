# PaperFlow 开发文档

> 开发文档按产品领域和工程主题持续维护；只有发布资料按版本归档。
> 每份文档的维护状态见下表（活跃：持续维护；归档：只读历史，只补勘误）。
> 最近更新：2026-08-06

## 总文档

| 文档 | 维护状态 |
| --- | --- |
| [AI Agent 开发规范](../AGENTS.md)：单人编排、skill 工作流、提交与验证约束 | 活跃 |
| [开发计划](development.md)：产品边界、优先级和各领域（论文 / ChatPaper / 我的）及扩展功能（社区 / 私信）现状与方向 | 活跃 |
| [代码结构原则](standards/code-structure.md)：所有开发必须遵守的架构与代码质量约束 | 活跃 |
| [Git 与任务集成管理](standards/version-control.md)：分支、worktree、提交、验证、回滚和集成规则 | 活跃 |
| [发布与兼容性管理](standards/release-management.md)：五层版本、环境渠道、数据/API 兼容和 Feature Flag 规则 | 活跃 |
| [开发技能](../.claude/skills/)：`/start`、`/develop`、`/test`、`/review`、`/finish`、`/version`、`/release`，入口见 AGENTS.md「Skill 工作流」 | 活跃 |
| [任务台账模板](templates/workstream-status.md)：单文件任务台账，skill 引用 | 活跃 |

## 任务与过程

| 文档 | 维护状态 |
| --- | --- |
| [任务台账说明](workstreams/README.md)：`docs/workstreams/<slug>/status.md` 的创建与归档规则 | 活跃 |

## 研究资料

| 文档 | 维护状态 |
| --- | --- |
| [热门论文筛选与数据源可行性研究](research/hot-paper-sources-2026-08.md)：热门信号、数据源、许可风险与推荐聚合架构 | 归档 |

## 维护规则

1. 开发计划统一在 `development.md` 维护，不为每个版本或领域复制一份。
2. 架构、协作和 Git 规则放在 `standards/`，不混入功能计划。
3. 只有发布计划、发布检查清单、发布审计和版本隐私资料进入 `releases/<version>/`。
4. 每个任务只维护自己的 `docs/workstreams/<branch-slug>/status.md` 台账，合并后归档保留，不删除、不更新。
5. 共享总文档由编排者更新；规范变更由编排者批准。
6. 功能状态统一使用“规划中、开发中、已完成、已延期、已取消”，并说明证据或后续方向。
7. 已发布资料只补充勘误和最终证据，不用后续开发计划覆盖历史状态。
8. 一个文档一个事实源，SKILL.md 只引用规范路径、不复制规范内容；改规范一处即生效。
