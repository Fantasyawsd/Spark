# Phase 4.5 UserPreferenceScore 与个性化排序任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

把匿名画像转化为推荐偏好分并接入混排（实现：workflow + openai/gpt-5.6-sol）：

1. `preference_score.py`：`compute_user_preference`——主题匹配（0.5）、会议匹配（0.2）、标题/摘要关键词重合（0.3），各分量归一化并按可用权重重归一化；无任何匹配返回 None（缺失不冒充 0）。
2. 引擎接入：`ScoreConfig` 增 `personalized_pool_ratio`（默认 0.4）；generate 带画像时构建 personalized 池（偏好分 > 0 的画像候选）并按配额轮转三池（quality/trend/personalized），personalized 池内按偏好分加权抽样；同作者/同主题多样性约束保持。
3. 无画像或 ratio=0 时行为与旧版完全一致（回归测试）。
4. `SCORE_VERSION` 升 score.v4，API 断言同步。
5. 测试：偏好分计算（含归一化与 None）、personalized 池选中、配额生效、无画像回归。

## 非目标

- 不改动客户端（纯服务端任务）。
- 60/20/10/10 混排实验为后续配置实验，本任务只实现三池配额机制。
- 回放兼容测试放 4.6。

## 分支与基线

- 分支：`feature/phase4-preference-ranking`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`6a73d54`
- 负责人：Fantasy（编排者，目标迭代授权）；实现：workflow + openai/gpt-5.6-sol

## 验收标准

- [x] 偏好分三分量加权与重归一化正确，无匹配为 None
- [x] 带画像时 personalized 池参与混排且按偏好加权抽样
- [x] 无画像/ratio=0 行为与旧版一致
- [x] SCORE_VERSION 升 score.v4 且 API 断言同步
- [x] `pytest` 全量通过（含新增用例，167 项）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| workflow 实现 agent（openai/gpt-5.6-sol） | preference_score.py + 三池混排 + score.v4，全量 165 项通过 | 2026-08-14 |
| workflow 审查 agent（openai/gpt-5.6-sol） | 两次调用均失败（provider 服务抖动）；编排者直接只读审查 diff（配额恒等、回归等价、多样性、加权抽样逐项核对） | 2026-08-14 |
| 编排者审查发现并修复 | 中文/短语关键词无法经英文 token 匹配 → 改子串匹配并过滤单字键（keyword_total 只计参与键）；补中文与单字键测试 | 2026-08-14 |
| `python -m pytest -q`（全量） | 167 项通过 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（推荐）：UserPreferenceScore 与个性化三池混排` | 实现（workflow + 编排者审查修复） | pytest 167 项通过 |

## 审查结论

编排者只读审查（workflow 审查 agent 两次失败后回退）：三池配额恒等（personalized/high/trend 和 = limit）、personalized 池仅由画像召回候选构成且按偏好加权、ratio=0/无画像路径与旧版等价（逐步核对 diff）、同作者/同主题约束在 personalized 分支生效。审查发现并修复中文/短语关键词匹配缺陷（英文 token 化无法匹配中文——改子串匹配）。无遗留阻断项。
