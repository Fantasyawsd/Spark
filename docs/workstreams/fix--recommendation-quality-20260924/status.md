# 推荐正确性与输入边界优化任务台账

## 基本信息

- 任务：校正推荐结果的偏好分归属，并使推荐输入的处理有界、可恢复。
- 分支：`fix/recommendation-quality-20260924`
- Worktree：`/mnt/data/agent-1`；控制树：`/mnt/data/Spark-control`。
- 真实远端基线：`7e71b36e7209da4e8d2385eba352b13d03e0fea0`。
- 执行：OpenAI Assistant；需求方：仓库使用者。
- 状态：待审查；定向验证完成，完整门禁未执行，不代表可合并。
- 最近更新：2026-09-24。
- 获取方式：GitHub 连接读取。容器无法解析 github.com，直接 clone 失败。本地保存经 Git blob SHA 校验的 9 个必要源模块和 1 个既有测试文件，不是完整仓库克隆。本地快照提交不等于真实远端基线；远端改动应以真实基线为父提交。

## 目标与非目标

目标：personalized 池返回选中论文自身的偏好分，其余池保持 0；已读 ID 最多读取前 5000 个输入项；无效画像和溢出数值被拒绝或降级，不泄漏预期可恢复异常。

非目标：不变更推荐权重、评分公式、版本、数据库 schema、Flutter 客户端、生产数据源或历史批次；不合并 main；不把局部审查称为全仓审计。

## 验收标准

- [x] 原始模块可复现偏好分错配、非 personalized 池分数错误、全量读取已读迭代器、超大整数与画像边界问题。
- [x] 正常抽样和尾部补位均满足 Phase 4.6 的字段契约。
- [x] 保留 Unicode、合法填充/无填充 Base64、数字字符串及正负权重边界兼容性。
- [x] 新增 21 项定向测试，加上既有画像测试 8 项，总计 29 项通过。
- [x] 600 组固定种子对照中，除 personalization_score 外，批次 ID、论文选择、池、权重和信号等输出保持一致。
- [ ] 完整服务端测试、真实 SQLite 集成回归和完整项目门禁。
- [ ] 人工审查、批准合并及 main 合并后归档。

## 写入范围

独占路径：

- `server/spark_papers/recommendation.py`
- `server/spark_papers/anonymous_profile.py`
- `server/tests/test_recommendation_quality_regressions.py`
- `server/tests/test_anonymous_profile_boundaries.py`
- 本台账

共享路径：无。已读取规范、模板与 `feature--phase4-mix-finalize` 台账，并查询当前远端分支；不触碰现有 UI 分支、总开发计划或 CI 配置。

## 实际变更与决策

| 项目 | 变更与理由 |
| --- | --- |
| 偏好分归属 | 不再使用候选扫描遗留的 paper_id；personalized 池读取选中 paper.paper_id 的偏好分，其他池为 0。普通配额与尾部补位均覆盖。 |
| 有界读取 | 用 set(islice(read_ids, 5000)) 替代先全量 list 再切片。上限仍是输入项数量，不是去重后数量。 |
| 数值容错 | 推荐信号和画像权重解析捕获 OverflowError；无效信号继续尝试有效来源，非法画像返回 None。 |
| 画像维度 | 规范化键名之前检查原始条目数，避免大量带空格同名键绕过 64 项限制，并提前拒绝超限维度。 |
| 编码边界 | Base64 严格校验非法字符；捕获 JSON 解码的 RecursionError；合法填充与无填充格式不变。 |
| 版本与兼容 | 修复既有字段契约，不调整评分公式；api.v1、paper.v1、profile.v1、score.v4 保持不变。 |

## 验证记录

环境：Python 3.13.5、pytest 9.0.2；Flutter/Dart 未安装。测试使用真实推荐引擎、评分、召回和 DTO；Repository 通过 autospec 测试替身隔离，不代表 SQLite/HTTP 集成验证。

| 检查 | 结果 |
| --- | --- |
| 同一组用例加载原始模块 | 失败，复现既有缺陷。例如选中论文偏好分应为 0.25，实际为 0.75，且错误值进入批次快照。原始输出保留在交付证据包。 |
| PYTHONPATH=server python -m pytest -q server/tests/test_anonymous_profile.py server/tests/test_anonymous_profile_boundaries.py server/tests/test_recommendation_quality_regressions.py | 29 passed，14 subtests passed。 |
| 标准库 unittest 对上述 3 个测试文件验证 | Ran 29 tests，OK。本地只有这些测试，不是全仓发现结果。 |
| python -m compileall -q server/spark_papers server/tests | 通过，范围为本地必要模块及上述测试。 |
| Python 3.10 语法解析 | 12 个文件通过 feature_version=(3, 10) 的 AST 解析；未在 Python 3.10 运行测试。 |
| 固定种子兼容对照 | 25 个种子 × 3 个 limit × 4 个配置 × 有/无画像 = 600 组；除修复字段外的输出逐项一致。 |
| 已读历史合成微基准 | 50 万条生成器、空仓储、启用 tracemalloc、3 次中位数：耗时约 1.698s → 0.019s；峰值约 30.10MB → 1.10MB；读取量 500000 → 5000，保留集合与 batch_id 一致。不是应用吞吐或真实数据库基准。 |

日志、JUnit XML、源码哈希清单、兼容对照和微基准脚本通过本次会话的交付证据包提供，不提交运行日志或缓存到仓库。

## 未完成与风险

1. 仅拉取必要模块，尚未运行完整服务端测试、SQL/HTTP 集成、Flutter analyze/test、Windows/Android 构建或设备人工验收。不得用历史台账中的 170 项通过记录替代本次验证。
2. 现有 Flutter CI 未包含 Python 测试；需单独补充 Python 验证门禁。本次未修改工作流或触发部署。
3. 负权重归一化存在待澄清语义：直接调用 compute_user_preference，单个匹配学科权重为 -1 时返回 1.0。此处只验证函数输出，不推断完整推荐效果；涉及评分口径，留待单独设计与版本决策。
4. 严格 Base64 会拒绝过去被忽略的非法字符；64 项限制按原始条目计算。这是预期的无效输入拒绝，不修改正常客户端编码器。
5. 本次没有加入整体请求字节上限、键长度限制或速率限制，不构成完整安全审计。
6. 历史已保存的错误 personalization_score 不自动回填；修复用于后续生成与记录。

## 审查与交付

- 本轮差异检查：限定两个生产模块、两个回归测试文件和本台账；未改评分公式和抽样权重。
- 独立审查：未执行；完整门禁未执行，不能宣称可合并或已完成发布验收。
- 下一步：在完整检出仓库运行服务端全量测试，人工审查差异，再按仓库规范决定集成。
- 远端交付：独立任务分支及草稿 PR；具体提交 SHA/PR 以实际创建后的交付报告为准，不预写成功状态。
- 回滚：未合并时放弃任务分支；若后续合并，使用 git revert 回退本任务提交。无数据库迁移或生产数据更改。

## 合并归档

未合并；main 集成提交、合并时间、集成验证与开发计划归档均未执行。
