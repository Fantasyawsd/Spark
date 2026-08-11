# 任务台账

## 基本信息

- 任务：完成 Phase 1 论文数据底座与 Phase 2 基础 Feed API
- 关联发布或里程碑：当前论文数据服务主线，不绑定发布版本
- 分支：`feature/paper-data-platform`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\feature--paper-data-platform`
- 基线提交：`948f3af`
- 负责人：Fantasy（编排者）
- 状态：开发中
- 最近更新：2026-08-11

## 目标

在不切换 Flutter Client 数据源的前提下，建立可离线重放的 AI 论文数据管道、Paper Database、版本化只读 Paper API，以及推荐/最新/主题基础 Feed 语义。

## 非目标

- 不实现账号、云同步、用户画像、A/B Test 或 Phase 3–5 高级推荐。
- 不恢复暂缓的 PDF 六问 AI 解读线，不接入生产 Flutter Client。
- 不提交 API Key、真实数据集、模型或 A100 运行产物。

## 验收标准

- [ ] Paper schema、来源字段、时间语义、可空值、版本与 provenance 可由 fixture 验证。
- [ ] HF/arXiv/外部增强适配器支持原始快照、游标/ETag、幂等重跑和失败保留最后成功快照。
- [ ] 稳定 `paper_id`、精确身份合并、低置信度匹配隔离和 AI 准入规则可审计。
- [ ] SQLite Paper Database 保存规范论文、来源观测、快照、匹配队列和推荐批次。
- [ ] `/api/v1` 提供详情、最新、主题、关注和推荐查询，支持版本、游标、时间筛选和已读过滤。
- [ ] 推荐实现 High Impact / Trending、质量/趋势分、年龄桶、无放回概率抽样和候选不足回补。
- [ ] 服务端单元/集成测试与 Flutter 现有静态检查均通过。

## 写入范围

### 独占路径

- `server/`
- `docs/workstreams/feature--paper-data-platform/status.md`

### 共享路径

- `docs/development.md`：仅在实现证据完成后更新 Phase 状态，由主 Agent 串行修改。

## 依赖关系

- 上游任务：`main@948f3af` 论文数据与推荐规划已合并。
- 外部接口或数据源：arXiv、Hugging Face Daily Papers、OpenAlex、Semantic Scholar、GitHub；测试使用本地 fixture。

## 实施计划

1. 建立领域 schema、身份和 AI 准入规则。
2. 建立 SQLite 存储、原始快照和同步运行器。
3. 实现来源适配器、身份合并、质量增强和只读 Paper API。
4. 实现基础推荐服务与 Feed API。
5. 补齐测试、文档和验证记录。

## 当前进度

- 已完成：创建独立 worktree；完成 PaperRecord、JSON Schema、来源 provenance、稳定身份、AI 准入、SQLite schema、原始快照和幂等同步运行器。
- 已完成：接入 arXiv Atom、HF Daily、OpenAlex、Semantic Scholar、GitHub enrichment 适配器；实现精确身份合并、低置信度匹配队列和 12 项服务端测试。
- 已完成：实现 `/api/v1` 详情、最新、主题、关注、推荐查询，以及质量/趋势评分、年龄桶、已读过滤、无放回抽样和推荐批次快照。
- 已完成：Flutter 全量静态检查、407 项客户端测试、development APK 与 Windows debug 构建均通过。
- 已完成：A100 `torch` Python 3.10 环境 fixture 回放 12 项通过；网络探测为 `OFFLINE`，因此未执行外部数据下载。
- 正在进行：真实 A100 数据回放和外部配额验证尚未执行，需待服务器联网后执行。
- 下一步：记录最终验证证据，提交任务检查点，并由编排者决定合入与 A100 部署。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-11 | 服务端使用 Python 标准库 + SQLite | 当前仓库没有服务端骨架；纯标准库保证离线 fixture 可重复验证 | 未来可替换 HTTP/DB 实现，API 契约保持稳定 |
| 2026-08-11 | Flutter Client 暂不切流 | 路线图明确 Phase 1.2 期间保持现有 arXiv 回退 | 本任务只交付服务端数据与 API |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `$env:PYTHONPATH=(Resolve-Path server).Path; python -m compileall -q server` | 通过 | 2026-08-11 |
| `$env:PYTHONPATH=(Resolve-Path server).Path; python -m unittest discover -s server/tests -v` | 12 项通过 | 2026-08-11 |
| CLI fixture sync smoke test | 通过；1 条 arXiv 记录写入 SQLite 与原始快照 | 2026-08-11 |
| `git diff --check` | 通过 | 2026-08-11 |
| `flutter analyze` | No issues found | 2026-08-11 |
| `flutter test` | 407 项通过 | 2026-08-11 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development` | 通过；`build/app/outputs/flutter-apk/app-development-debug.apk`；164,811,140 bytes；SHA-256 `9726F13C3465E2EA2366688477AB84D2BD34610527AA7C558729A7878687474F` | 2026-08-11 |
| `flutter build windows --debug --dart-define=SPARK_ENV=development` | 通过；`build/windows/x64/runner/Debug/spark.exe`；1,279,488 bytes；SHA-256 `BCA00A3389F00027B4EABACE9616ED415DB560B933338E7162A3BFA812C13F30` | 2026-08-11 |
| `ssh a100 ... curl -sI https://pypi.org` | 服务器 `PR4910W` 可访问；网络 `OFFLINE`；`/data2/fanjiahao` 存在 | 2026-08-11 |
| A100 `/data2/fanjiahao/anaconda3/envs/torch/bin/python -m unittest discover -s server/tests -v` | 12 项通过；Python 3.10 兼容性验证 | 2026-08-11 |

## 审查结论

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

交付一个不切换 Flutter Client 的服务端纵向闭环：第三方来源响应先原子保存为快照，再经 AI 准入、身份解析和规范化写入 SQLite Paper Database；`/api/v1` 提供详情、最新、主题、关注和推荐 Feed，推荐批次保留评分特征与抽样种子。

### 实际变更

- 领域与业务逻辑：Paper schema、稳定 `paper_id`、AI 准入、低置信度匹配队列、质量/趋势分、年龄桶和无放回抽样。
- 数据与基础设施：SQLite schema、raw snapshot、ETag/cursor 状态、arXiv/HF/OpenAlex/Semantic Scholar/GitHub 适配器和标准库 HTTP API。
- 界面与交互：无，Client 暂不切流。
- 测试与工具：12 项 Python 单元/集成测试、CLI fixture smoke、JSON Schema。
- 文档：服务端 README 与 `paper.v1` schema。

### 兼容性与迁移

- 本地数据迁移：无；新增服务端 SQLite schema v1。
- API 或领域契约变化：新增 `/api/v1`，无现有 Client 兼容负担。
- 旧版本兼容性：无影响。

### 已知风险与回滚

- 已知风险：真实外部接口配额、许可和字段变化需在部署前重新核验；A100 当前无外网，只完成了离线 fixture 回放；本任务不提交线上数据。
- 回滚方式：按提交逆序 `git revert`；服务端数据库可删除并从原始快照重建。

### 文档更新建议

- 合入后将 `docs/development.md` 中 Phase 1/2 状态更新为“服务端实现完成、待 A100 数据回放/部署验收”，不把 fixture 测试误记为生产数据已上线。

### 未完成与后续工作

- Phase 3 实时热点、Phase 4 个性化、Phase 5 高级推荐，以及 Flutter Client 切流另行排期。
