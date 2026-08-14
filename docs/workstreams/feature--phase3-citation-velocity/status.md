# Phase 3.2 Citation velocity 短期增速补全任务台账

> 状态：已合并
> 最近更新：2026-08-14

## 目标

补全推荐引擎已有权重但一直无来源的引用速度信号：

1. OpenAlex 同步保留原始 `counts_by_year`（逐年引用计数）。
2. 新增 `citation_velocity.py`：`citation_velocity`（近 3 个日历年年均引用）与 `short_citation_velocity`（近 12 个月引用估算，需当年与前一年数据，年内线性插值）。
3. ingest 派生写入 `signals.openalex` 并附 `derived` 来源证据；数据不足返回 `null` 不冒充 0。
4. schema 契约增补三个字段。

## 非目标

- 不修改推荐引擎权重与归一化（3.7 统一调整）。
- 不改动 Semantic Scholar 侧同步字段。
- 不回填历史库（仅从本批同步起生效）。

## 分支与基线

- 分支：`feature/phase3-citation-velocity`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`a8b0aab`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] OpenAlex 归一化保留 `counts_by_year` 原始结构
- [x] 近 3 年年均引用与近 12 个月估算计算正确（含年内比例）
- [x] 缺当年或前一年数据时 `short_citation_velocity` 为 `null`
- [x] ingest 后 signals 含派生值并有 `derived` 证据
- [x] `pytest` 全部通过（含新增用例）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `python -m pytest tests/test_citation_velocity.py` | 9 项通过 | 2026-08-14 |
| `python -m pytest -q`（全量） | 107 项通过 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（论文数据）：按逐年引用派生 citation velocity` | 实现 | pytest 107 项通过 |

## 合并归档

- 合并方式：本地快进合并（`main` `a8b0aab..47d2470`）
- 最终集成提交：`47d2470`
- 合并时间：2026-08-14
- 集成验证：合并后 `python -m pytest -q` 107 项通过；无 Flutter 客户端改动。
- 真实后续项：3.3 Web Heat 信号契约与存储（下一迭代基线）。

## 审查结论

只读审查：`citation_velocity.py` 纯函数（3 年年均 + 12 个月插值，缺年返回 None）；ingest 对称于 3.1 派生并附 `derived` 证据；schema 契约同步。无阻断项。
