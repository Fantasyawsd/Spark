# Phase 3.5 Trend Boost 衰减任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

为已核验热点施加 24–72 小时短期推荐增益并快速衰减：

1. `trend_boost.py`：`BoostConfig`（window_hours=72、half_life_hours=24、gain=1.0）与 `compute_trend_boost`（纯函数：无 `trend_detected_at`、未来时间或窗口外 → 1.0；窗口内 `1 + gain × 2^(−age/half_life)`）。
2. 推荐引擎接入：仅对 `signals.web_heat.trend_detected_at` 存在的论文，trend 综合分乘 boost 系数；子信号归一化不受影响。
3. `SCORE_VERSION` 由 `score.v1` 升为 `score.v2`（分数口径变化）。
4. 测试：衰减曲线、边界、确定性、引擎接入（仅 web_heat 论文获得增益）。

## 非目标

- 不把 web_heat 子信号加入 trend_weights（3.7 统一处理权重版本）。
- 不做 Client 展示（3.6）。

## 分支与基线

- 分支：`feature/phase3-trend-boost`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`c12ab08`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] boost 纯函数覆盖边界与衰减曲线
- [x] 引擎仅对带 trend_detected_at 论文施加增益
- [x] 无热点论文分数与既有口径一致
- [x] SCORE_VERSION 递增到 score.v2
- [x] `pytest` 全部通过（含新增用例）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `python -m pytest tests/test_trend_boost.py` | 10 项通过 | 2026-08-14 |
| `python -m pytest -q`（全量） | 136 项通过（含 test_api score_version 断言同步为 score.v2） | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（推荐）：24–72 小时 Trend Boost 指数衰减` | 实现 | pytest 136 项通过 |

## 审查结论

只读审查：boost 为纯函数（无信号/未来/窗口外→1.0，窗口内指数半衰），仅对带 `trend_detected_at` 论文施加；trend 展示分数 clamp 到 [0,1]，抽样权重用 boosted 值；SCORE_VERSION 升 score.v2 并有 API 断言同步。无阻断项。
