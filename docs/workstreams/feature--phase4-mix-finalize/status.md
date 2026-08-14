# Phase 4.6 三信号混排收口与回放兼容任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

Phase 4 服务端收口（SCORE_VERSION 已于 4.5 升 score.v4）：

1. `RecommendationItem` 增补 `personalization_score` 字段；`recommendation_to_api` 透出；personalized 池条目携带偏好分，其余池为 0。
2. 回放兼容：batch 按 score_version 追溯（v3/v4 并存可读）；同 seed 不同版本生成不同 batch_id；特征快照已含 personalization.preference（沿用 4.5）。
3. 测试：API 透出、池条目偏好分、版本追溯与 batch_id 隔离。

## 非目标

- 不再变更评分口径（SCORE_VERSION 保持 score.v4）。
- 不做客户端改动（纯服务端收口）。
- 60/20/10/10 混排实验留后续配置实验。

## 分支与基线

- 分支：`feature/phase4-mix-finalize`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`22e06a4`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] RecommendationItem/API 透出 personalization_score
- [x] personalized 池条目偏好分 > 0，其余池为 0
- [x] v3/v4 batch 并存追溯与 batch_id 隔离测试
- [x] `pytest` 全量通过（含新增用例，170 项）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `python -m pytest tests/test_recommendation_personalization.py` | 3 项通过 | 2026-08-14 |
| `python -m pytest -q`（全量） | 170 项通过 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（推荐）：三信号混排收口与 batch 版本追溯` | 实现 | pytest 170 项通过 |

## 审查结论

只读审查：RecommendationItem 字段顺序调整已同步全部三处构造与 reconstruct；dto 透出 personalization_score（客户端手写 fromJson 忽略未知键，无兼容影响）；batch 追溯测试确认 v3/v4 并存且同 seed 不同版本 batch_id 隔离。无阻断项。
