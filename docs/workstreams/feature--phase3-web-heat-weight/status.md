# Phase 3.7 Web Heat 接入 TrendScore 权重版本任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

把 3.3/3.4 建立的 web_heat 信号纳入 TrendScore 权重（Phase 3 收口）：

1. ${BT}_signal${BT} 读取 ${BT}signals.web_heat.web_heat_score${BT}；${BT}ScoreConfig.trend_weights${BT} 纳入 web_heat 并重归一化（新权重和仍为 1.0）。
2. ${BT}SCORE_VERSION${BT} 由 score.v2 升为 score.v3（分数口径变化），API 断言同步。
3. 回放兼容：历史 batch（score.v1/v2）记录保持可读、按版本追溯，不与新版本混用；补测试。

## 非目标

- 不改变 quality 权重与混排结构。
- 不做客户端改动（纯服务端任务）。

## 分支与基线

- 分支：`feature/phase3-web-heat-weight`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`95fc943`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] web_heat_score 进入 trend 信号并归一化
- [x] trend_weights 新版本权重和为 1.0
- [x] SCORE_VERSION 升 score.v3，API 断言同步
- [x] 历史 batch 按版本追溯测试
- [x] `pytest` 全部通过（含新增用例）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `python -m pytest tests/test_web_heat_scoring.py` | 4 项通过 | 2026-08-14 |
| `python -m pytest -q`（全量） | 140 项通过（test_api 断言同步 score.v3） | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（推荐）：web_heat 进入 TrendScore 权重版本` | 实现 | pytest 140 项通过 |

## 审查结论

只读审查：trend_weights 纳入 web_heat（0.20）并保持总和 1.0，缺失信号经既有重归一化不惩罚；SCORE_VERSION 升 score.v3；batch 表按 score_version 追溯并存。纯服务端改动，Flutter 产物与 3.6 相同，按台账说明不重复双目标构建。无阻断项。
