# 推荐链路结构与质量门禁

## 基本信息

- 分支：`refactor/recommendation-structure-20260924`
- 上游：草稿 PR #5 / `fix/recommendation-quality-20260924`
- 远端基线：`64cf4051ccbdeef3bdcf7ecdd8b74a6269c13dfc`
- Worktree：`/mnt/data/spark-structure-work/agent-1`；控制树为同级 `Spark`
- 状态：待审查
- 更新时间：2026-09-24
- 授权：用户要求下一步优化代码结构整体质量；未授权合并或发布

## 目标与验收

拆分推荐用例、纯评分与纯抽样职责，隔离 API DTO 与持久化快照，补齐服务端结构和测试门禁。

- [x] 固定种子下推荐输出、分数和批次标识与 PR #5 一致
- [x] 评分辅助入口与生产批量入口共用实现
- [x] 用例只向仓储传递领域批次；API DTO 不再进入推荐依赖图
- [x] 持久化字段、取整、UTC 格式和旧批次写入接口不变
- [x] 记录定向验证与未执行项；新草稿 PR 保留上游依赖

## 非目标

不改变评分版本/公式、API/数据库 schema、Flutter 生产代码、数据源、界面或已知业务缺陷。

## 写入范围

- 独占：`server/spark_papers/recommendation*.py`、`models.py`、`ports.py`、`storage.py`；对应服务端测试；本台账。
- 共享：新增 `.github/workflows/server-ci.yml`；不修改既有 Flutter CI 或共享规范。

## 环境与证据

容器无法解析 GitHub 域名；经 GitHub 连接分段获取源码，并按 Git blob SHA 校验。当前本地为可追溯的部分源码验证树，不是完整克隆；本地快照 Git 提交与真实远端基线分开记录。远端提交将以真实基线树进行逐文件更新，不删除未下载文件。

## 实际实现

- `recommendation.py` 从 600 行收敛至 127 行；`generate` 从 218 行收敛至 43 行，负责召回、评分、抽样、补全领域数据和提交批次。
- 新增 `recommendation_policy.py`、`recommendation_scoring.py`、`recommendation_sampling.py`：配置、统一评分和请求内抽样状态分别维护。抽样条目使用命名字段，集中构造 `RecommendationItem`；补全论文改用 `dataclasses.replace`。
- 新增领域 `RecommendationBatch`；`RecommendationRepository.save_recommendation_batch` 接收领域对象。`PaperStore` 在数据适配层调用独立 `recommendation_snapshot.py`，保留既有 `record_batch` 写入接口和 JSON 字段/取整/时间格式。
- 修正 `PaperRepository.list_papers_by_keyword` 缺失的 `to_date` 参数，并以 autospec 调用覆盖真实关键词召回契约。
- 新增静态 AST 依赖扫描测试：服务端静态导入无环、领域/推荐用例禁止依赖 API/DTO/存储适配器、快照映射不依赖 API。包含扫描器自身测试；不声称覆盖动态导入。
- 新增多学科 P99、缺失/零/溢出、单次迭代、空结果、固定种子特征快照和存储映射测试，以及完整 `PaperStore` 的 SQLite 集成测试。
- 新增独立 Server CI（Python 3.10/3.13）：编译、架构测试、标准库 unittest 服务端全量发现；显式安装打包迁移测试所需 setuptools>=68 和 wheel。保留 Flutter 既有分层/依赖图门禁，不修改 Flutter 源码或原有 CI。

## 验证记录

| 验证 | 本轮结果 |
| --- | --- |
| 原有局部测试（重构前） | 29 passed, 14 subtests passed |
| 局部测试（重构后，明确排除 PaperStore 集成文件） | 47 passed, 228 subtests passed |
| 600 组固定种子完整输出对照 | 全部逐项一致，包含偏好分、API 展示字段、论文顺序和批次 ID |
| Python 3.10 AST 语法解析 | 已获取源码与新增测试全部通过；不能替代 Python 3.10 运行 |
| Git diff check | 通过 |
| 完整服务端及真实 PaperStore 集成 | 本地缺少完整仓库，未执行；已配置 CI，结果需以真实运行记录为准 |
| Flutter analyze/test、Windows/Android 构建、设备验收 | 未执行，未修改客户端；仍不能替代合并门禁 |

验证命令：

```sh
PYTHONPATH=server python -m pytest -q server/tests \
  --ignore=server/tests/test_recommendation_batch_storage.py
# 完整仓库 / CI：
python -m unittest discover -s server/tests -t server -v
```

测试环境为 Python 3.13.5 / pytest 9.0.2。本地测试只针对明确获取的源码子集，不代表全仓通过。参考语义：Python 官方 unittest Test Discovery 文档。

初次 CI（仅新增工作流，代码仍为 PR #5 基线）：run 35960410485，Python 3.10 通过，Python 3.13 在 191 项中的 wheel 打包迁移测试出错（pip wheel --no-build-isolation）。新增构建依赖安装步骤后，再对结构提交执行完整 CI；不把初次失败计为重构回归。

## 兼容性与风险

- 生产批量评分与抽样规则保持 `score.v4`；600 组对照验证了合成样本，不能证明所有输入等价。
- **辅助函数语义调整**：`score_paper` 统一使用生产的分组 P99 上限；多学科大样本和无对应比较组时，结果会与旧辅助函数不同。这收敛了开发计划 M11 的双实现问题。生产批量评分保持原口径，不宣称所有公共辅助函数行为零变化。
- `ScoreConfig`、`age_bucket`、`score_paper` 的原导入路径保留。仓储内部端口改为领域批次；新增仓储替身需要实现 `save_recommendation_batch`。
- API/数据库 schema 和历史批次不迁移；不回填历史偏好分。不改变生产数据源和个人数据。
- 负权重语义、并发 SQLite 连接、物化候选过滤、ChatPaper 单文件存储等既有问题不在本轮内；全仓质量审计未完成。
- 回滚：撤销本轮结构提交；无数据库逆向迁移。上游 PR #5 独立保留。

## 当前状态与交付

- 状态：待审查；草稿 PR #6 基于 PR #5 分支，未合并。
- 正式 `/review`、`/finish` 与合并归档尚未执行；不得按本文件将任务标为已合并。
- 核对了现有客户端架构测试和开发计划中的结构债。本轮落地范围为服务端推荐边界和门禁，不宣称完成全客户端结构重构。
- 合并前：审查堆叠分支关系、运行完整服务端/SQLite 集成，并按仓库要求补齐适用门禁。
