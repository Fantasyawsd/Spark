# PaperFlow 开发文档

> 开发文档按产品领域和工程主题持续维护；只有发布资料按版本归档。
> 最近更新：2026-08-02

## 总文档

- [AI Agent 开发规范](../AGENTS.md)：所有 Agent 的开发约束、多 Agent 协作和交付工作流。
- [开发总路线](development-roadmap.md)：产品边界、长期能力、优先级和持续技术路线。
- [代码结构原则](standards/code-structure.md)：所有开发必须遵守的架构与代码质量约束。
- [Git 与多 Agent 集成管理](standards/version-control.md)：分支、worktree、提交、验证、回滚和集成规则。
- [发布与兼容性管理](standards/release-management.md)：五层版本、环境渠道、数据/API 兼容和 Feature Flag 规则。
- [Workstream 状态模板](templates/workstream-status.md)和[开发报告模板](templates/development-report.md)：分支事实记录。

## 产品开发文档

- [论文频道、索引与阅读改进](product/papers/channels-and-reading.md)
- [论文开发路线](product/papers/roadmap.md)
- [ChatPaper 开发路线](product/chatpaper/roadmap.md)
- [我的开发路线](product/profile/roadmap.md)

后续按 `product/papers/`、`product/chatpaper/`、`product/profile/` 等业务领域扩展，不按计划版本复制开发文档。

## 协作与审查

- [Workstream 注册与协作](workstreams/README.md)
- [2026-08 架构审查](reviews/architecture-2026-08.md)
- [早期论文与社区体验记录](reviews/paper-experience-history.md)

## 发布归档

| 版本 | 状态 | 入口 |
| --- | --- | --- |
| 0.1.0 | 功能代码候选，等待发布门 | [0.1.0 发布资料](releases/0.1.0/README.md) |

## 维护规则

1. 产品开发文档按业务领域维护唯一事实源，不为每个版本复制一份。
2. 架构、协作和 Git 规则放在 `standards/`，不混入功能计划。
3. 只有发布计划、发布检查清单、发布审计和版本隐私资料进入 `releases/<version>/`。
4. 并行分支只维护自己的 `workstreams/<branch-slug>/` 状态与报告。
5. 共享总文档由集成负责人根据开发报告统一更新。
6. 功能状态统一使用“规划中、开发中、已完成、已延期、已取消”，并说明证据或后续方向。
7. 已发布资料只补充勘误和最终证据，不用后续开发计划覆盖历史状态。
