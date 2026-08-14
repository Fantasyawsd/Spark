# Phase 3.3 Web Heat 信号契约与存储任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

为 LLM Trend Scout（3.4）与 Trend Boost（3.5）建立 Web Heat 信号的契约与写入接口：

1. schema 增补 `signals.web_heat` 定义：`web_heat_score`、`web_mentions`、`web_source_count`、`trend_detected_at`、`trend_reason`、`trend_topics`。
2. `PaperStore.record_web_heat`：幂等写入/覆盖论文的 web_heat 信号，附 `web_heat` 来源证据；未知论文返回 False 不创建残缺论文。
3. API 层验证：`paper_to_api` 已透出全部 signals，补断言测试。

## 非目标

- 不实现 LLM 发现逻辑（3.4）。
- 不把 web_heat 接入 TrendScore 权重（3.7）。
- 不做 Client 展示（3.6）。

## 分支与基线

- 分支：`feature/phase3-web-heat`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`d1dd7a9`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] schema 定义与 CONTEXT.md「Web 热度信号」语义一致
- [x] `record_web_heat` 幂等写入、覆盖旧值、未知论文不创建
- [x] provenance 证据含 `web_heat` 来源
- [x] API 响应包含 web_heat 字段
- [x] `pytest` 全部通过（含新增用例）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `python -m pytest tests/test_web_heat.py` | 5 项通过 | 2026-08-14 |
| `python -m pytest -q`（全量） | 112 项通过 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（论文数据）：建立 Web Heat 信号契约与写入接口` | 实现 | pytest 112 项通过 |

## 审查结论

只读审查：schema 六字段与 CONTEXT.md 语义一致；`record_web_heat` 幂等覆盖、未知论文拒绝创建残缺记录；API 经既有 signals 透出并有断言。无阻断项。
