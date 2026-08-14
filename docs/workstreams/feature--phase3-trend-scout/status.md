# Phase 3.4 LLM Trend Scout 候选发现与身份核验任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

实现 LLM Trend Scout 的候选发现与身份核验闭环（写入 3.3 建立的 web_heat 契约）：

1. 端口抽象：`TrendScoutLlmPort`（结构化候选发现）与 `TrendScoutPort`（运行编排），生产 LLM 适配器密钥只从环境变量读取，不进仓库。
2. 运行编排 `TrendScoutRunner`：LLM 发现候选（标题/arXiv ID/DOI/热度证据/原因/主题）→ 库内身份核验（arXiv/DOI 精确匹配优先，标题模糊匹配只做候选）→ 命中且准入论文写 `record_web_heat`；未核验候选进入待核验记录，不写残缺论文。
3. 幂等与可重放：同一批候选重复运行覆盖同一次 `trend_detected_at` 结果；快照记录来源证据。
4. mock LLM 测试覆盖发现→核验→写入全链路；未命中、模糊匹配、损坏输出均有测试。

## 非目标

- 不把 web_heat 接入 TrendScore 权重（3.7）。
- 不做 Client 展示（3.6）。
- 不实现真实 Web 抓取（候选来源由 LLM 端口提供）。

## 决策记录

- 2026-08-14：目标指定复杂任务用 gpt-5.6-sol，经 workflow 三次探测（gpt-5.6-sol / gpt-5.6 / gpt5.6-sol）该模型在当前环境均不可用（agent 返回失败），默认模型可用。决策：3.4 保持 workflow 编排，模型回退为默认模型执行；本台账保留该证据。

## 分支与基线

- 分支：`feature/phase3-trend-scout`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`7187d67`
- 负责人：Fantasy（编排者，目标迭代授权）；实现：workflow + gpt-5.6-sol

## 验收标准

- [x] 端口与 runner 分离，mock LLM 可注入
- [x] 身份核验优先精确 ID，模糊匹配不自动合并
- [x] 命中论文写入 web_heat 且幂等
- [x] 未核验候选不创建论文、不写信号
- [x] 生产 LLM 适配器从环境变量读密钥，仓库无密钥
- [x] `pytest` 全部通过（含新增用例）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| workflow 实现 agent（默认模型回退） | trend_scout.py + 14 项测试，无既有文件改动 | 2026-08-14 |
| workflow 审查 agent | 通过，无阻断项；观察项 A（match_queue 重复入队）、B（matched 计数语义）、C（模糊匹配全表扫描）为非阻断 | 2026-08-14 |
| `python -m pytest -q`（本机复验） | 126 项通过（18.27s） | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（论文数据）：LLM Trend Scout 候选发现与身份核验` | 实现（workflow） | pytest 126 项通过 |
| 待提交 | `文档（台账）：记录 3.4 实现审查与观察项` | 文档 | git diff --check |

## 审查结论

workflow 审查 agent 结论：通过，无阻断项。身份核验符合「精确 ID 优先、模糊只入待核验队列、未核验不写信号」；密钥仅从环境变量读取；测试覆盖校验/命中/拒绝/队列/跳过/计数 14 项。非阻断观察项：A match_queue 无唯一约束重复入队（既有共享设计，趋势侧后续可去重）；B matched 计数含被标题校验拒绝的精确命中，语义建议后续在 docstring 说明；C 模糊匹配全表扫描与 ingest 同款既有模式。
