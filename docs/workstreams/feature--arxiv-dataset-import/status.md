# 任务台账

## 基本信息

- 任务：Phase 2.5 真实论文数据落库与端到端验收
- 关联发布或里程碑：论文数据与基础 Feed 主线，不绑定发布版本
- 分支：`feature/arxiv-dataset-import`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\feature--arxiv-dataset-import`
- 基线提交：`c01a6d252135cdfe82261a9c60be9fb0a137a62a`
- 负责人：Fantasy（编排者）
- 状态：开发中
- 最近更新：2026-08-12 12:20

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
- [x] HF Daily、Semantic Scholar 与 GitHub 完成有界的真实同步、快照和落库验证；同步失败保留最近成功状态。
- [x] 推荐年龄桶、批次标识和异常引用排除满足可回放契约，并在真实库复验。

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

- 已完成：可恢复导入器、字段契约、集合式索引和有界推荐查询；675,168 篇论文、675,168 个唯一 arXiv ID、99,577 条会议增强和 2,895 个唯一 OpenAlex ID 已真实落库。
- 已完成：14 天 HF Daily 326 条、Semantic Scholar 500 请求/498 有效返回、GitHub 50 条真实增强均保留原始快照、source observation 和 provenance。
- 已完成：真实库健康、详情、最新、主题、会议、关注、推荐、已读排除、年龄桶和批次隔离验证；服务端 23 项测试通过。
- 已完成：修复年龄桶跨桶回补、不同请求复用 `batch_id`、非 arXiv 来源覆盖规范字段和异常 OpenAlex 引用进入 quality pool 的问题；真实索引复验 0 违规。
- 已完成：Dart 格式、`flutter analyze`、428 项 Flutter 测试和服务端 23 项测试通过；会议/刷新修复后的 profile/release 产物需在最终收尾重新构建。
- 已完成：根据编排者验收反馈开放 19 个真实会议频道；推荐刷新优先排除当前频道缓冲区，再补历史已读 ID，旧列表不会因刷新消失。
- 正在进行：等待编排者在已重启的 Windows development App 中复验会议频道和推荐净增量。
- 下一步：人工复验通过后更新 Phase 2/2.5 状态，进入 `/test`、`/review` 和合并收尾。
- 阻塞项：无；人工 App 验收尚待执行。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-12 | 新增 Phase 2.5，不把真实数据接入归入 Phase 3 | 真实落库和规模验收是 Phase 1/2 的原始完成条件，不属于热点能力增强 | Phase 1/2 保持开发中，直至 Phase 2.5 验收通过 |
| 2026-08-12 | 主输入使用 `spark-arxiv-ai-full.jsonl`，会议目录只作增强 | 实测主文件有 674,969 行，`by-year-venue-label/` 只有 99,577 行且不存在 `_none` 文件，与 README 的“全部 AI 论文”描述不一致 | 主文件建立完整底库；会议目录按 arXiv ID 增强 `_matched_venue` 和 `_matched_label`，禁止替代底库 |
| 2026-08-12 | 继续使用 SQLite 并建立独立新库 | 编排者已明确选择 SQLite；独立数据库便于验证和回滚 | 不覆盖现有 50 篇临时数据库 |
| 2026-08-12 | 使用分层证据路径验收 Phase 2.5 | 单一 fixture 或接口 200 响应不能证明真实数据阶段完成 | 单元测试验证字段/恢复；全量报告和 SQL 验证数量/唯一性；接口计时验证性能；Windows App 人工验证用户行为 |
| 2026-08-12 | 推荐请求最多携带 200 个排除 ID，当前频道列表优先 | URL 查询参数必须有界；刷新需保证旧列表不消失且新 batch 不重复当前列表 | App 先加入当前推荐缓冲区 ID，再用剩余额度补历史已读 ID；服务端仍保留 5,000 个输入上限 |
| 2026-08-12 | development App 开放 19 个真实会议频道 | 编排者验收确认客户端没有会议入口，但真实库已有 99,577 篇会议增强和会议 API | 频道管理会议页可添加/移除 NeurIPS、ICML、CVPR 等会议；production 仍受功能边界控制 |
| 2026-08-12 | discovery source 与 enrichment source 分层 | GitHub、Semantic Scholar 和 OpenAlex 提供字段增强，不代表论文从这些来源进入目录 | `discovery_sources` 仅保留 arXiv/HF；其他来源保留在 source observation 和 provenance |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 本地数据集逐行计数 | 主 JSONL `674,969` 行 / `1,306,961,453` bytes；会议分区 `99,577` 行 / `202,295,639` bytes，共 `1,049` 文件且无 `_none` 文件 | 2026-08-12 |
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
| `flutter build windows --debug --dart-define=SPARK_ENV=development` | 通过；历史 development debug 构建证据，仅作客户端连接回归，不作为发布产物 | 2026-08-12 |
| `sync-external --hf-days 14 --semantic-scholar-limit 500 --github-limit 50` | 通过；HF 326 条、Semantic Scholar 498/500、GitHub 50 条，0 unmatched/0 rejected；写入真实快照，耗时约 560.6 秒 | 2026-08-12 |
| SQLite 全量来源与推荐核验 | 通过；675,168 论文/唯一 arXiv ID，source observation：HF 326、Semantic Scholar 498、GitHub 50；HF heat 326、Semantic Scholar citation 498、GitHub stars 194、GitHub links 195；quality outlier 0、Trending 非零 326、错误年龄桶 0 | 2026-08-12 |
| Paper API HTTP 端到端核验 | 通过；health 675,168；最新/主题/会议/关注各返回真实论文；推荐 20 条无重复，10 条已读交集为 0，不同 limit 的 batch_id 不同 | 2026-08-12 |
| `flutter pub get` | 通过；Flutter 3.44.8，依赖解析成功 | 2026-08-12 |
| `.\tool\verify_changed_dart_format.ps1` | 通过；17 个 Dart 文件，0 个需格式化 | 2026-08-12 |
| `flutter analyze` | 通过；No issues found | 2026-08-12 |
| `flutter test` | 通过；426 项全部通过 | 2026-08-12 |
| `flutter build apk --profile --flavor development --dart-define=SPARK_ENV=development` | 通过；`build/app/outputs/flutter-apk/app-development-profile.apk`，90,680,457 bytes，SHA-256 `6FA4FB557A62F98E3D676FC09B1F4C44AF9ABF90B2C7497FA93985DCF5E955F6`；因无 `android/key.properties`，按规范使用 profile | 2026-08-12 |
| `flutter build windows --release --dart-define=SPARK_ENV=development` | 通过；`build/windows/x64/runner/Release/spark.exe`，101,888 bytes，SHA-256 `D818C73AC821F64BD61F6FCA692DE66EA2CE8DCFC3EFEC05BD1E5870064F5F95` | 2026-08-12 |
| 会议频道与推荐刷新缺陷红测试 | 修复前失败：会议页无 ICML/NeurIPS 可添加项；推荐刷新只携带已读 2 个 ID，未排除当前 10 篇缓冲区 | 2026-08-12 |
| 会议频道与推荐刷新定向回归 | 通过；会议频道可添加/移除，当前缓冲区优先进入 200 个排除 ID，App 已重启加载新代码 | 2026-08-12 |
| discovery source 数据校正 | 通过；675,168 篇保持不变，发现来源仅 arXiv 674,969 / HF 326；GitHub 50、Semantic Scholar 498、OpenAlex 2,895 等观测完整保留 | 2026-08-12 |
| 推荐净增量控制器测试 | 通过；初始 10 篇，刷新请求排除旧 10 篇，返回新 20 篇后列表恰好 30 篇，旧 10 篇顺序保留 | 2026-08-12 |
| 反馈修复后的完整静态门禁 | 通过；服务端 23 项、Dart 格式 20 文件、`flutter analyze` 无问题、Flutter 428 项全部通过 | 2026-08-12 |

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
| `79b642d` | 新增（论文数据）：接入真实外部来源与 Phase 2.5 入口 | Phase 1/2/2.5 真实同步检查点 | HF/Semantic Scholar/GitHub 真实同步、来源快照、索引优化、推荐回归、定时脚本和计划文档完成；Windows App 人工验收待完成 |
| `b0ba4c0` | 修复（论文频道）：补齐会议入口与推荐净增量 | Phase 2 反馈修复检查点 | development App 开放 19 个会议频道；当前列表优先进入推荐排除集合；10→30 净增量和 discovery source 迁移测试通过 |

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

- 已知风险：会议增强只覆盖 `99,577/674,969`，来自 comments/journal-ref 正则匹配，未标注不代表未录用；OpenAlex 高引数据输入 2,901 条且 29 条异常引用已排除 quality pool；HF/Semantic Scholar/GitHub 按免费接口预算做有界同步。
- 回滚方式：停止新 API 进程并重新指向旧 SQLite；代码按任务提交 `git revert`。

### 文档更新建议

- Phase 2.5 的真实来源、会议入口和推荐净增量回归已经通过；只剩 Windows development App 人工复验与本轮代码对应的 profile/release 重建，不能在用户未确认前关闭 Phase 2/2.5。

### 未完成与后续工作

- Windows development App 人工验收待完成；确认后补充人工证据。
- `tool/sync_paper_sources.ps1` 已提供定时调用入口，部署后的 Task Scheduler 注册在合并到 `main` 后执行；Phase 3–5 保持后续阶段。

## 合并归档（合并后在 main 补齐）

- 最终状态：待合并
- 合入分支：`main`
- 最终集成提交：待填写
- Pull Request：无
- 合并时间：待填写
- main 集成验证：待填写
- 开发计划更新：待填写
- 最终后续项：待填写
