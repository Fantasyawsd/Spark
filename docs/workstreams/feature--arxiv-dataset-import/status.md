# 任务台账

## 基本信息

- 任务：Phase 2.5 真实论文数据落库与端到端验收
- 关联发布或里程碑：论文数据与基础 Feed 主线，不绑定发布版本
- 分支：`feature/arxiv-dataset-import`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\feature--arxiv-dataset-import`
- 基线提交：`c01a6d252135cdfe82261a9c60be9fb0a137a62a`
- 负责人：Fantasy（编排者）
- 状态：开发中
- 最近更新：2026-08-12 14:30

## 目标

使用本地 Spark arXiv 数据集建立可重复、可恢复的真实 SQLite Paper Database，接入 OpenAlex 高引、HF Daily、Semantic Scholar 与 GitHub 真实增强，并在真实规模下完成 Paper API、基础推荐和 Windows development App 验收，以补齐 Phase 1/2 尚未完成的交付条件。

## 非目标

- 不实现 Phase 3 的实时 Web 热点、citation velocity 或 GitHub star velocity。
- 不实现 Phase 4/5 的用户画像、Embedding、Two-Tower、Learning to Rank 或 A/B Test。
- 不迁移 MySQL，不在 Git 中提交 JSONL、SQLite、快照、日志或其他运行产物。
- 不把本机部署冒充 A100、staging 或 production 部署。

## 验收标准

- [x] 规范字段契约覆盖本地 arXiv、会议标签和 OpenAlex 高引数据；来源年份不冒充会议年份，未知字段保持 `null`。
- [x] 导入器逐行、分批处理 `by-year-venue-label/`，内存占用不随数据集总大小线性增长，并支持失败保留与恢复。
- [x] 真实数据库论文数量与源数据核验结果一致，arXiv ID 唯一，拒绝和重复记录有可追溯报告。
- [x] `openalex-ai-top.jsonl` 只增强已存在论文，记录精确匹配、未匹配和异常信号数量，不创建残缺论文。
- [x] SQLite 索引构建和推荐候选查询不把约 67.5 万篇论文一次性加载进 Python 内存。
- [x] 健康、详情、最新、主题、会议、关注和推荐 API 在真实数据库上通过；不同 seed 生成不同可重放推荐 batch。
- [ ] Windows development App 展示真实论文，推荐刷新返回新 batch 并与现有列表合并，由编排者人工验收。
- [x] 服务端测试、Flutter 定向测试、格式检查和静态分析通过；真实导入数量、耗时、数据库大小和接口检查有记录。
- [ ] HF Daily、Semantic Scholar 与 GitHub 完成有界的真实同步、快照和落库验证；同步失败保留最近成功状态。
- [ ] 推荐年龄桶、批次标识和异常引用排除满足可回放契约，并在真实库复验。

## 写入范围

### 独占路径

- `server/schema/paper.v1.json`
- `server/spark_papers/dataset.py`
- `server/tests/test_dataset.py`
- `docs/workstreams/feature--arxiv-dataset-import/status.md`

### 共享路径

- `server/spark_papers/normalization.py`：只补本地数据集规范化。
- `server/spark_papers/storage.py`：只补批量导入、集合式索引和有界候选查询。
- `server/spark_papers/recommendation.py`、`server/spark_papers/ports.py`：只调整真实规模候选契约。
- `server/spark_papers/cli.py`、`server/README.md`：只增加数据集导入与部署入口。
- `lib/src/app/spark_app.dart`、`lib/src/features/papers/application/`：只补真实推荐刷新、增量合并和已读 ID 传递。
- `test/paper_controller_test.dart`、`test/paper_api_*`：只补 Paper API 与 Feed 端到端行为测试。
- `docs/development.md`：只校正 Phase 1/2 状态并维护 Phase 2.5。

## 依赖关系

- 上游任务：Phase 1/2 服务端实现 `main@7af6861`；development Paper API Client `main@2c7aeed`。
- 外部接口或数据源：`C:\Users\Fantasy\Desktop\Spark-worktrees\Spark-arxiv-dataset\spark-arxiv-ai-full.jsonl`、`by-year-venue-label/`、`openalex-ai-top.jsonl`。

## 实施计划

1. 校正 Phase 1/2 状态，定义 Phase 2.5 与真实数据验收条件。
2. 固化本地 arXiv、会议标签和 OpenAlex 字段映射，增加流式、分批、可恢复导入器。
3. 将索引刷新改为集合式 SQL，将推荐候选改为有界数据库查询。
4. 先以小规模真实记录验证，再导入完整主 JSONL，并执行会议标签和 OpenAlex 增强。
5. 在新 SQLite 上完成 API、推荐批次和 Windows development App 验收。
6. 接入 HF Daily、Semantic Scholar 和 GitHub 的真实有界同步，补齐定时执行入口与快照证据。
7. 修复审查发现的年龄桶回补、推荐批次标识冲突和异常引用参与评分问题，并刷新真实索引复验。

## 当前进度

- 已完成：可恢复导入器、字段契约、集合式索引和有界推荐查询；674,969 篇 arXiv 主库、99,577 条会议增强和 2,901 条 OpenAlex 增强已真实落库。
- 已完成：真实库健康、详情、最新、主题、会议、关注、推荐和已读排除验证；服务端 18 项测试及客户端推荐刷新、增量合并、已读 ID 传递定向测试通过。
- 已完成：Dart 格式、`flutter analyze`、426 项 Flutter 测试、development APK 和 Windows debug 构建全部通过。
- 已完成：修复年龄桶跨桶回补、不同请求复用 `batch_id` 和异常 OpenAlex 引用参与评分的问题；服务端 19 项回归通过。
- 正在进行：补齐 HF Daily、Semantic Scholar、GitHub 的真实同步，并修复推荐年龄桶、批次标识和异常引用评分问题。
- 下一步：完成真实来源与推荐回归后，由编排者人工确认真实论文、数据源标识、推荐刷新增量合并和频道内容。
- 阻塞项：无；人工 App 验收尚待执行。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-11 | 新增 Phase 2.5，不把真实数据接入归入 Phase 3 | 真实落库和规模验收是 Phase 1/2 的原始完成条件，不属于热点能力增强 | Phase 1/2 保持开发中，直至 Phase 2.5 验收通过 |
| 2026-08-11 | 主输入使用 `spark-arxiv-ai-full.jsonl`，会议目录只作增强 | 实测主文件有 674,969 行，`by-year-venue-label/` 只有 99,577 行且不存在 `_none` 文件，与 README 的“全部 AI 论文”描述不一致 | 主文件建立完整底库；会议目录按 arXiv ID 增强 `_matched_venue` 和 `_matched_label`，禁止替代底库 |
| 2026-08-11 | 继续使用 SQLite 并建立独立新库 | 编排者已明确选择 SQLite；独立数据库便于验证和回滚 | 不覆盖现有 50 篇临时数据库 |
| 2026-08-11 | 使用分层证据路径验收 Phase 2.5 | 单一 fixture 或接口 200 响应不能证明真实数据阶段完成 | 单元测试验证字段/恢复；全量报告和 SQL 验证数量/唯一性；接口计时验证性能；Windows App 人工验证用户行为 |
| 2026-08-12 | 推荐请求最多携带 200 个本地已读 ID | URL 查询参数必须有界，同时让服务端在刷新时排除近期已读论文 | App 每次推荐请求实时读取本地集合、去重排序并截断；服务端仍保留 5,000 个输入上限 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 本地数据集逐行计数 | 主 JSONL `674,969` 行 / `1,306,961,453` bytes；会议分区 `99,577` 行 / `202,295,639` bytes，共 `1,049` 文件且无 `_none` 文件 | 2026-08-11 |
| `import-dataset --batch-size 1000` | 通过；主库 `674,969` 导入、0 重复、0 拒绝；会议 `1,049` 文件 / `99,577` 条全部匹配；OpenAlex `2,901` 条全部匹配，数据库约 `4.86 GB` | 2026-08-12 |
| SQLite 数量与索引核验 | `papers=674,969`、唯一 arXiv ID `674,969`、Latest `674,969`、Channel `1,421,373`、Author `3,109,720`、Venue `99,577`、Candidate `714,969`（含全量池和 8 个各 5,000 的物化池） | 2026-08-12 |
| OpenAlex 增强核验 | `2,901` 条输入和匹配、`2,895` 个唯一 OpenAlex ID、`29` 条 `citation_count_outlier` 标记、0 未匹配、0 拒绝 | 2026-08-12 |
| `GET /api/v1/health` | 通过；`status=ok`、`schema_version=api.v1`、`paper_count=674969` | 2026-08-12 |
| 真实 API 定向计时 | 最新/主题/关注热请求约 `5–20 ms`，会议约 `87–102 ms`，推荐约 `0.45–0.58 s`；接口均返回真实论文 | 2026-08-12 |
| 两个推荐 seed + 第二批 `read_ids` | 通过；产生不同 `batch_id`，第二批与第一批 10 个已读 ID 交集为 0 | 2026-08-12 |
| `PYTHONPATH=server; python -m unittest discover -s server/tests -v` | 通过；18 项全部通过 | 2026-08-12 |
| 推荐可回放修复后的服务端全量测试 | 通过；19 项全部通过，覆盖年龄桶标签、批次请求隔离和异常引用排除 | 2026-08-12 |
| `flutter test test/paper_controller_test.dart` | 通过；32 项全部通过，覆盖首次远程替换 seed、刷新前插去重、200 个已读 ID 上限和实时集合更新 | 2026-08-12 |
| `.\tool\verify_changed_dart_format.ps1` | 通过；18 个改动 Dart 文件均符合当前 formatter | 2026-08-12 |
| `flutter analyze` | 通过；No issues found | 2026-08-12 |
| `flutter test` | 通过；426 项全部通过 | 2026-08-12 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development` | 通过；`build/app/outputs/flutter-apk/app-development-debug.apk`，`164,834,576` bytes，SHA-256 `580341603E2983BE586B22772E563514761628ED487876CC24518B567B5699C6` | 2026-08-12 |
| `flutter build windows --debug --dart-define=SPARK_ENV=development` | 通过；`build/windows/x64/runner/Debug/spark.exe`，`1,279,488` bytes，SHA-256 `B9AA1FDD196CB2E83C26C274F86337C1D4A544315BFC06CE7748AC87DC3EA5A8` | 2026-08-12 |

## 审查结论

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `b886587` | 新增（论文数据）：落地真实数据底库与基础 Feed 验收 | Phase 1/2/2.5 实现检查点 | 674,969 篇真实底库、API/推荐规模验证、Flutter 426 项测试和双目标 development 构建通过；Windows App 人工验收待完成 |
| `8df10b4` | 修复（论文推荐）：保证批次与评分结果可回放 | Phase 2 正确性检查点 | 年龄桶回补、批次标识和异常引用评分问题修复；服务端 19 项通过 |

## 交付准备（合并前收集）

### 交付摘要

完成本地真实论文底库、会议/OpenAlex 增强、全量 SQLite 索引与 Paper API 规模验证；development Flutter Client 已接入推荐新 batch、增量合并和已读过滤，等待最终 Windows App 人工验收。

### 实际变更

- 领域与业务逻辑：推荐引擎按有界候选、年龄桶、High Impact/Trending 池和 seed 生成批次；客户端刷新前插新论文并按 `paper_id` 去重，推荐请求携带有界已读集合。
- 数据与基础设施：新增可恢复的 JSONL 批量导入器、租约/断点/拒绝记录、外部 ID 索引、会议/OpenAlex 增强、集合式索引和物化推荐池。
- 界面与交互：无计划内视觉改动；development App 首次远程成功替换内置 seed，后续刷新合并新 batch。
- 测试与工具：新增导入恢复、并发租约、字段映射、只增强已有论文、有界候选及客户端刷新/已读过滤测试；服务端、Flutter、格式、分析和双目标 development 构建门禁均通过。
- 文档：Phase 1/2 状态与 Phase 2.5 进度。

### 兼容性与迁移

- 本地数据迁移：新建独立 SQLite，不覆盖旧数据库。
- API 或领域契约变化：保持 `/api/v1` 顶层响应兼容，补充已存在的 `metadata`、`signals` 嵌套契约。
- 旧版本兼容性：production Client 数据源不变。

### 已知风险与回滚

- 已知风险：会议增强只覆盖 `99,577/674,969`；OpenAlex 高引数据仅覆盖 2,901 条且 29 条引用数被标记为异常；HF Daily、Semantic Scholar 和 GitHub 尚无真实同步数据。
- 回滚方式：停止新 API 进程并重新指向旧 SQLite；代码按任务提交 `git revert`。

### 文档更新建议

- Phase 2.5 人工验收和完整门禁通过后，再依据实际剩余的 HF/GitHub 数据项决定 Phase 1/2 是否可关闭，不能只因本地 arXiv 导入成功就提前标记完成。

### 未完成与后续工作

- Windows development App 人工验收待完成。
- HF Daily 定时镜像与真实 GitHub/Semantic Scholar 增强仍是 Phase 1 的剩余项；Phase 3–5 保持后续阶段。

## 合并归档（合并后在 main 补齐）

- 最终状态：待合并
- 合入分支：`main`
- 最终集成提交：待填写
- Pull Request：无
- 合并时间：待填写
- main 集成验证：待填写
- 开发计划更新：待填写
- 最终后续项：待填写
