# 任务台账

## 基本信息

- 任务：Phase 2.5 真实论文数据落库与端到端验收
- 关联发布或里程碑：论文数据与基础 Feed 主线，不绑定发布版本
- 分支：`feature/arxiv-dataset-import`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\feature--arxiv-dataset-import`
- 基线提交：`c01a6d252135cdfe82261a9c60be9fb0a137a62a`
- 负责人：Fantasy（编排者）
- 状态：待合并
- 最近更新：2026-08-13

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
- [x] Windows development App 展示真实论文，推荐刷新返回新 batch 并与现有列表合并，由编排者人工验收。
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
- `server/spark_papers/sources.py`、`server/spark_papers/pipeline.py`、`tool/sync_paper_sources.ps1`：只补 arXiv OAI 日增量、分页断点、限流和定时入口。
- `server/spark_papers/database/migrations/`、`server/pyproject.toml`：只补 OAI 同步状态的版本化迁移与安装包资源声明。
- `lib/src/app/spark_app.dart`、`lib/src/features/papers/application/`：只补真实推荐刷新、增量合并和已读 ID 传递。
- `test/paper_controller_test.dart`、`test/paper_api_*`、`test/ui_preview_test.dart`：只补 Paper API、Feed 与论文导航刷新行为测试。
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
8. 将已选中的底部「论文」导航键作为当前频道刷新入口；从其他一级页面切回论文页时只导航，不额外刷新。
9. 将 arXiv OAI 接入可恢复日增量：独立保存日期水位与分页 token，逐页落原始快照，失败保留最后成功断点，完整窗口结束后仅刷新一次索引。
10. 修正人工验收发现的推荐刷新合并方向：旧 batch 保持原位，新 batch 追加到下方，用户继续向上滑即可进入新论文；同步修正错误的前插回归测试。

## 当前进度

- 已完成：可恢复导入器、字段契约、集合式索引和有界推荐查询；680,199 篇论文、680,199 个唯一 arXiv ID、99,577 条会议增强和 2,895 个唯一 OpenAlex ID 已真实落库。
- 已完成：14 天 HF Daily 326 条、Semantic Scholar 500 请求/498 有效返回、GitHub 50 条真实增强均保留原始快照、source observation 和 provenance。
- 已完成：真实库健康、详情、最新、主题、会议、关注、推荐、已读排除、年龄桶和批次隔离验证。
- 已完成：修复年龄桶跨桶回补、不同请求复用 `batch_id`、非 arXiv 来源覆盖规范字段和异常 OpenAlex 引用进入 quality pool 的问题；真实索引复验 0 违规。
- 已完成：本轮 `/test` 自动化验收通过；服务端 48 项、Dart 格式 21 个文件、`flutter analyze` 和 Flutter 429 项测试均通过，Python/PowerShell/diff 静态检查通过。目标构建按规范留到 `/finish` 合入 `main` 后执行。
- 已完成：根据编排者验收反馈开放 19 个真实会议频道；推荐刷新优先排除当前频道缓冲区，再补历史已读 ID，旧列表不会因刷新消失。
- 已完成：已处于论文一级页面时重复点击底部「论文」导航键会强制刷新当前频道；从其他一级页面返回论文页时只导航、不额外刷新。
- 已完成：编排者在重新启动的 Windows development App 中人工确认论文导航刷新通过。
- 已完成：arXiv OAI 日增量已接入官方端点；独立完成水位、窗口级 checkpoint、分页 token、3 秒限流、逐页快照、坏记录整页重试、token 失效后窗口重放、持久删除和完整窗口单次索引刷新均已实现。
- 已完成：真实同步 `2026-07-31` 至 `2026-08-12` 共 18 页；AI 准入 8,864 条、非 AI 排除 13,516 条、0 unmatched、0 rejected、0 failed page，论文总数从 675,168 增至 680,199。
- 已完成：SQLite OAI 状态已通过不可变迁移升级到数据库版本 1，真实库完成水位为 `2026-08-12T00:00:00+00:00`，迁移前后论文数量不变，Paper API 健康检查仍返回 680,199。
- 已完成：修正推荐刷新合并方向；首次远程加载仍替换 seed，后续刷新保留旧 batch 和当前论文位置，将去重后的新 batch 追加到列表下方。
- 下一步：按编排者指令进入 `/finish`，合入 `main` 后执行集成回归、双目标构建和最终归档。
- 阻塞项：无。
- 验收反馈：推荐刷新前插不符合竖向刷论文交互；已改为旧 batch 在前、新 batch 在后。编排者在修复版 Windows development App 启动后确认可以进入 `/finish`，本轮人工验收通过。

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
| 2026-08-12 | OAI 完成水位、活动窗口和分页 token 分开保存 | 未完成页只能推进抓取时间，不能提前宣告窗口完成；损坏 token 仍需保留原窗口边界 | `sync_state` 通过版本化迁移增加 `completed_through`、`window_from`、`window_until`；第一页请求前先建立窗口 checkpoint |
| 2026-08-12 | OAI 同步只允许全量目录且拒绝未来窗口 | 集合子集共用全局水位会跳过其他论文；当前日期为 2026-08-12，之后日期尚未发生 | CLI 不暴露 set 参数，任何 `until` 晚于 2026-08-12 的窗口直接失败且不推进水位 |

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
| 论文导航刷新红绿测试 | 修复前重复点击已选中的「论文」导航仍只有初始化 1 次 Feed 请求；修复后产生第 2 次 `forceRefresh=true` 请求，从 ChatPaper 返回论文页不增加请求 | 2026-08-12 |
| 论文导航刷新完整静态门禁 | 通过；Dart 格式检查 21 个文件、`flutter analyze` 无问题、Flutter 429 项全部通过；标准与需求一致性审查无阻断项 | 2026-08-12 |
| 论文导航刷新 Windows 人工验收 | 通过；编排者确认在论文页重复点击底部「论文」键可触发刷新 | 2026-08-12 |
| arXiv OAI 真实增量同步 | 通过；窗口 `2026-07-31` 至 `2026-08-12` 共 18 页，AI 准入 8,864、非 AI 排除 13,516、0 unmatched / rejected / failed page，论文数 `675,168 → 680,199` | 2026-08-12 |
| OAI 后真实 SQLite 核验 | 通过；680,199 篇/唯一 arXiv ID、重复 0；arXiv discovery 680,187、HF discovery 326、交集 314、HF-only 12；Latest/All Candidate 均 680,199、Author 3,136,579 | 2026-08-12 |
| SQLite 版本迁移与 API 健康 | 通过；`PRAGMA user_version=1`、完成水位 `2026-08-12T00:00:00+00:00`，迁移前后论文数不变；health 返回 `status=ok`、`api.v1`、680,199 | 2026-08-12 |
| `python -m unittest discover -s server/tests -v` | 通过；48 项全部通过，覆盖窗口/checkpoint、分页恢复、坏页重试、持久删除、失败非零退出、旧库迁移、未来版本拒绝及 wheel 安装迁移 | 2026-08-12 |
| Python / PowerShell / diff 静态检查 | 通过；全部服务端与测试 Python 文件可编译，`tool/sync_paper_sources.ps1` 语法解析成功，迁移目录仅含 `001_oai_sync_windows.sql`，`git diff --check` 通过 | 2026-08-12 |
| wheel 构建与隔离安装 smoke | 通过；迁移 SQL 进入 `spark_papers/database/migrations/` package data，安装后的 `PaperStore` 可将旧库升级到版本 1 | 2026-08-12 |
| `/test` 服务端门禁 | 通过；48 项服务端测试全部通过，Python 编译、PowerShell 语法和 `git diff --check` 均通过 | 2026-08-12 |
| `/test` `./tool/verify_changed_dart_format.ps1` | 通过；21 个 Dart 文件，0 个需格式化 | 2026-08-12 |
| `/test` `flutter analyze` | 通过；No issues found | 2026-08-12 |
| `/test` `flutter test` | 通过；429 项全部通过 | 2026-08-12 |
| `/test` 目标构建 | 本阶段按规范不重复执行；development APK 与 Windows release 构建留到 `/finish` 合入 `main` 后统一执行 | 2026-08-12 |
| 推荐刷新追加方向红绿回归 | 修复前测试准确失败：前 10 篇为新 batch；修复后旧 10 篇保持在前、新 20 篇追加到下方，当前论文位置保持不变 | 2026-08-12 |
| 推荐刷新追加方向完整静态门禁 | 通过；Dart 格式检查 22 个文件、`flutter analyze` 无问题、Flutter 429 项全部通过 | 2026-08-12 |
| Windows development App 最终人工验收 | 通过；修复版 App 使用 680,199 篇真实数据库启动，编排者确认可以进入 `/finish`；推荐刷新保留旧 batch 并将新 batch 追加到下方 | 2026-08-13 |

## 审查结论

- 审查日期：2026-08-12
- 阻断项：最终双轴复审无阻断项；早期发现的集合水位污染、旧数量、缺阅读链接、未来窗口、坏页推进水位、内联迁移、迁移未打包、外部失败被吞和 checkpoint 污染成功时间均已修复。
- 缺陷：无未关闭缺陷。
- 结论：arXiv OAI 日增量、版本化迁移和统一定时入口的 Spec / Standards 双轴复审无阻断项；审查后新增的推荐刷新追加修复已完成只读增量复核及 429 项 Flutter 回归，无新增阻断项。自动化门禁和 Windows App 人工验收均已通过，可进入 `/finish`。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `b886587` | 新增（论文数据）：落地真实数据底库与基础 Feed 验收 | Phase 1/2/2.5 实现检查点 | 674,969 篇真实底库、API/推荐规模验证、Flutter 426 项测试和双目标 development 构建通过；Windows App 人工验收待完成 |
| `8df10b4` | 修复（论文推荐）：保证批次与评分结果可回放 | Phase 2 正确性检查点 | 年龄桶回补、批次标识和异常引用评分问题修复；服务端 19 项通过 |
| `79b642d` | 新增（论文数据）：接入真实外部来源与 Phase 2.5 入口 | Phase 1/2/2.5 真实同步检查点 | HF/Semantic Scholar/GitHub 真实同步、来源快照、索引优化、推荐回归、定时脚本和计划文档完成；Windows App 人工验收待完成 |
| `b0ba4c0` | 修复（论文频道）：补齐会议入口与推荐净增量 | Phase 2 反馈修复检查点 | development App 开放 19 个会议频道；当前列表优先进入推荐排除集合；10→30 净增量和 discovery source 迁移测试通过 |
| `1eec33e` | 新增（论文导航）：重复点击论文键刷新频道 | Phase 2 交互补充检查点 | 重复点击已选中的论文导航强制刷新当前频道；从其他一级页面返回只导航；Dart 格式、静态分析、429 项 Flutter 测试和只读审查通过 |
| `266b5d5` | 新增（论文数据）：接入 arXiv OAI 可恢复日增量 | Phase 1 严格收口检查点 | 18 页真实 OAI 增量、680,199 篇唯一论文、SQLite v1 迁移、wheel 安装迁移、失败非零退出、48 项服务端测试和双轴复审通过 |
| `b3680e7` | 修复（论文推荐）：将刷新批次追加到阅读流下方 | Phase 2 人工验收修复检查点 | 旧 batch 保持原位，新 batch 去重后追加到下方；Dart 格式 22 文件、静态分析和 Flutter 429 项测试通过；Windows App 已重启待复验 |

## 交付准备（合并前收集）

### 交付摘要

完成本地真实论文底库、会议/OpenAlex 增强、arXiv OAI 可恢复日增量、版本化 SQLite 迁移、全量索引与 Paper API 规模验证；development Flutter Client 已接入推荐新 batch、向下增量合并和已读过滤，Windows App 人工验收通过。

### 实际变更

- 领域与业务逻辑：推荐引擎按有界候选、年龄桶、High Impact/Trending 池和 seed 生成批次；客户端刷新前插新论文并按 `paper_id` 去重，推荐请求携带有界已读集合。
- 数据与基础设施：新增可恢复的 JSONL 批量导入器、租约/断点/拒绝记录、外部 ID 索引、会议/OpenAlex 增强、集合式索引和物化推荐池；补充 arXiv OAI 独立窗口水位、分页 checkpoint、逐页快照、删除处理与 wheel 内版本化迁移。
- 界面与交互：无视觉改动；development App 首次远程成功替换内置 seed，后续刷新合并新 batch；已选中的底部论文导航键同时作为当前频道刷新入口。
- 测试与工具：新增导入恢复、并发租约、字段映射、只增强已有论文、有界候选、客户端刷新/已读过滤、论文导航刷新、OAI 分页恢复、失败退出、数据库迁移和 wheel 安装测试；服务端 48 项、Flutter、格式、分析和既有双目标 development 构建证据均通过。
- 文档：Phase 1/2 状态与 Phase 2.5 进度。

### 兼容性与迁移

- 本地数据迁移：初始导入使用独立 SQLite；现有 Paper Database 通过 `PRAGMA user_version` 和随 wheel 发布的不可变 SQL 从版本 0 升级到版本 1，保留论文数据并回填已完成 OAI 水位。
- API 或领域契约变化：保持 `/api/v1` 顶层响应兼容，补充已存在的 `metadata`、`signals` 嵌套契约。
- 旧版本兼容性：production Client 数据源不变。

### 已知风险与回滚

- 已知风险：会议增强只覆盖 `99,577/680,199`，来自 comments/journal-ref 正则匹配，未标注不代表未录用；OpenAlex 高引数据输入 2,901 条且 29 条异常引用已排除 quality pool；HF/Semantic Scholar/GitHub 按免费接口预算做有界同步；定时任务注册仍待合并后在目标环境执行。
- 回滚方式：停止新 API 进程并重新指向旧 SQLite；代码按任务提交 `git revert`。

### 文档更新建议

- Phase 2.5 的真实来源、会议入口和推荐净增量回归及 Windows development App 人工验收已经通过；合入 `main` 后按 `/finish` 运行双目标构建并更新开发计划。

### 未完成与后续工作

- Windows development App 人工验收已通过；`tool/sync_paper_sources.ps1` 已提供定时调用入口，目标环境 Task Scheduler 注册在合并到 `main` 后按部署计划执行；Phase 3–5 保持后续阶段。

## 合并归档（合并后在 main 补齐）

- 最终状态：待合并
- 合入分支：`main`
- 最终集成提交：待填写
- Pull Request：无
- 合并时间：待填写
- main 集成验证：待填写
- 开发计划更新：待填写
- 最终后续项：待填写
