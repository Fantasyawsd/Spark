# Phase 3.1 GitHub star velocity 真实计算任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

把 GitHub star velocity 从「来源直传或恒为 None」改为由服务端历史观测真实计算：

1. 新增 `github_star_history` 表，按 `(paper_id, observed_at)` 幂等记录每次同步的 stars 观测。
2. 新增 `star_velocity.py`：30 天窗口增速计算；少于两个观测或窗口内无增量信息时返回 `null`（缺失信号不冒充 0）。
3. ingest 流程在合并写入后追加观测并派生 `signals.github.star_velocity`，使推荐引擎现有 `trend.github_star_velocity` 权重直接获得真实信号。
4. 契约：`schema/paper.v1.json` 增补 github 信号字段定义。

## 非目标

- 不改动推荐引擎的权重、归一化与混排逻辑（后续 3.7 统一调整）。
- 不回填历史库中已有论文的 star 历史（仅从本批同步起积累观测）。
- 不新增外部数据源或同步入口。

## 分支与基线

- 分支：`feature/phase3-star-velocity`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`0627186`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] 迁移创建 `github_star_history` 表并可通过既有迁移测试
- [x] 观测追加幂等（同 paper_id + 同 observed_at 不产生重复行）
- [x] 30 天窗口增速计算正确；单观测/缺失/零窗口返回 null
- [x] ingest 后 `signals.github.star_velocity` 由历史派生
- [x] `pytest` 全部通过（含新增用例）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `python -m pytest tests/test_star_velocity.py` | 9 项通过（0.26s） | 2026-08-14 |
| `python -m pytest -q`（全量） | 98 项通过（20.65s） | 2026-08-14 |
| 迁移测试更新（版本 1→2、002 入 wheel、历史表断言） | 3 个既有迁移测试同步版本号后通过 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（论文数据）：按历史观测派生 GitHub star velocity` | 实现 | pytest 98 项通过 |
| 待提交 | `文档（计划）：拆分 Phase 3 子任务并归档 3.1 台账` | 文档 | git diff --check |

## 审查结论

只读审查：新增 `star_velocity.py` 纯函数计算模块（缺失/单观测返回 None，负增长裁为 0）；`storage.ingest` 在事务内幂等追加观测并派生 `signals.github.star_velocity`，同时写入 `derived` 来源证据；schema 契约与实现一致；3 个既有迁移测试仅同步版本号断言，无行为放宽。无阻断项。
