# Phase 4.4 Personalized Pool 候选召回任务台账

> 状态：已合并
> 最近更新：2026-08-14

## 目标

服务端按匿名画像召回个性化候选（实现：workflow + pd/gpt-5.6-sol）：

1. 新模块 `personalized_pool.py`：`PersonalizedPoolConfig`（每类候选上限、最小权重阈值）与 `build_personalized_candidates`——画像主题经 channel_index 精确召回、会议经 venue_index、关键词经 title/abstract LIKE（每键 LIMIT，标注性能边界）；去重并排除未准入/撤回。
2. 相似召回端口 `SimilarPaperRecallPort`：标题/摘要关键词重合度基础实现 `TitleKeywordSimilarityRecall`，向量 Embedding 接口契约预留（未来替换实现）。
3. `RecommendationEngine.generate` 接收 anonymous_profile 后把画像候选并入候选集（评分与配额留 4.5/4.6）。
4. 测试：召回准确性、去重、排除、上限、相似端口 mock、generate 候选包含画像论文。

## 非目标

- 不接入 UserPreferenceScore（4.5）与混排配额（4.6）。
- 不实现向量 Embedding（接口契约预留即可）。

## 分支与基线

- 分支：`feature/phase4-personalized-pool`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`35e10fc`
- 负责人：Fantasy（编排者，目标迭代授权）；实现：workflow + pd/gpt-5.6-sol

## 验收标准

- [x] 画像主题/会议/关键词三类召回正确且去重
- [x] 未准入/撤回论文被排除
- [x] 每类候选上限与权重阈值生效
- [x] SimilarPaperRecallPort 可注入 mock，基础实现通过重合度召回
- [x] generate 携带画像时候选集包含画像相关论文
- [x] `pytest` 全量通过（含新增用例，157 项）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| workflow 实现 agent（pd/gpt-5.6-sol） | personalized_pool.py + 6 项测试，全量 155 项通过 | 2026-08-14 |
| workflow 审查 agent（pd/gpt-5.6-sol） | 2 个阻断项：as_of 上界缺失、LIKE 性能边界未标注 | 2026-08-14 |
| 阻断修复（编排者） | 全部召回路径施加 as_of 上界（含相似端口与关键词查询）；LIKE 转义参数化并标注临时方案边界；补未来论文排除与 wildcard 转义测试 | 2026-08-14 |
| `python -m pytest -q`（全量） | 157 项通过 | 2026-08-14 |

## 性能边界

- 关键词召回为临时 LIKE 扫描方案：受 `max_keywords=24` 与 `per_key_limit=50` 约束，仅适配当前单机库规模；库规模显著增长时迁移 FTS5/关键词索引（迁移边界以此记录为准）。
- 相似召回基础实现按同 subjects 有界召回（每主题 ≤200）+ 有界全池回退（limit×10），复杂度可控；向量 Embedding 经 `SimilarPaperRecallPort` 替换实现。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（推荐）：Personalized Pool 画像候选召回` | 实现（workflow + 阻断修复） | pytest 157 项通过 |

## 合并归档

- 合并方式：本地快进合并（`main` `35e10fc..2d540cc`）
- 最终集成提交：`2d540cc`
- 合并时间：2026-08-14
- 集成验证：合并后 `python -m pytest -q` 157 项通过；纯服务端任务，Flutter 产物无变化，按台账说明不重复双目标构建。
- 真实后续项：4.5 UserPreferenceScore 与个性化排序（下一迭代基线）。

## 审查结论

workflow 审查 agent 首次结论：2 个阻断项（as_of 上界缺失、LIKE 性能边界未标注），均已在实现中修复并有测试与台账证据（未来论文排除、wildcard 转义、性能边界小节）。复验全量 157 项通过。无遗留阻断项。
