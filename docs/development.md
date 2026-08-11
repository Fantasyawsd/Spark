# Spark 开发路线图

> 状态：持续维护
> 最近更新：2026-08-11

本文是开发计划的唯一文件，记录产品边界、当前能力、开发任务与后续方向。
发布范围和证据归入 `releases/<version>/`；架构、Git 与发布规则分别见
[`standards/code-structure.md`](standards/code-structure.md)、
[`standards/version-control.md`](standards/version-control.md)、
[`standards/release-management.md`](standards/release-management.md)。论文来源、外部信号和频道语义见
[`../CONTEXT.md`](../CONTEXT.md)。

---

## 1. 产品概览

### 1.1 产品边界

Spark 面向个人研究者，核心闭环由三个一级能力组成：

| 模块 | 职责 |
| --- | --- |
| **论文** | 发现、筛选、阅读、收藏和管理论文 |
| **ChatPaper** | 围绕通用问题或指定论文进行可恢复的 AI 对话 |
| **我的** | 管理个人研究数据、收藏分组、阅读记录、主题和 DeepSeek 凭据 |

社区与私信作为未来扩展功能保留（见第 5 节），当前不进入生产导航。
通知、账号体系、云同步和内容发布暂不进入当前生产导航——只有在重新确认产品价值、数据来源和维护成本后才纳入规划。

### 1.2 本阶段目标

本阶段以论文数据服务和基础 Feed 为主线，按以下顺序推进：

1. 建立只收录 AI 论文的服务端 Paper Database，完成 arXiv/HF/OpenAlex/Semantic Scholar/GitHub 离线同步、身份解析、去重和字段增强。
2. 提供版本化 Paper API，完成推荐、最新、主题和会议频道的数据供给；关注频道保持现有语义。
3. 落地无账号阶段的 High Impact / Trending 推荐、时间分层、已读过滤和概率抽样。
4. 保留论文 AI 解读与 ChatPaper PDF 线的既有设计，但本阶段暂缓实现；继续维护相关论文、side chat 和个人数据恢复等客户端任务。

实时热点、个性化和高级推荐按 §3.1 的 Phase 3–5 继续演进，不与本阶段基础数据任务并行抢占范围。

---

## 2. 当前状态

### 2.1 当前生产能力

| 模块 | 当前状态 |
| --- | --- |
| 应用入口 | 论文 / ChatPaper / 我的三个一级页面形成单机闭环；社区和私信不在生产导航 |
| 论文目录 | Client 直连 arXiv Atom，使用版本化本地缓存与内置种子回退；推荐、关注、最新固定频道及 arXiv 主题频道可用 |
| 频道体验 | 频道偏好、列表状态、浏览位置、发布时间筛选和懒加载按频道保存；主题/会议管理页已存在 |
| 论文阅读 | 提供 Abstract、中文摘要、关键词、作者、AI 解读、相关论文六页结构；中文摘要与内容关键词按需生成并版本化缓存 |
| 本地研究数据 | 搜索、点赞、收藏、评论、分享、阅读历史、稍后阅读和自定义收藏分组保存在设备本地 |
| ChatPaper | 提供主聊天和论文聊天、DeepSeek BYOK 流式回答、联网搜索、会话设置、本地恢复，以及可选 PDF 文本提取、分块和页码引用 |
| 我的 | 提供收藏与历史入口、主题外观、本地数据管理、DeepSeek Key 管理、隐私说明和开源许可 |

### 2.2 当前边界与已知缺口

- 仍无账号、跨设备同步或 Spark 服务端；论文目录由 Client 直连 arXiv，所有互动、会话和偏好保存在当前设备。
- 推荐与最新频道尚未接入独立服务端语义，当前仍使用现有 arXiv 目录能力；A100 Paper Database、推荐服务和 Paper API 均未实现。
- 会议频道只有领域模型和管理入口，尚无可靠 Venue 数据源；OpenAlex、Semantic Scholar、GitHub 增强尚未进入生产论文链路。
- 六问结构化 AI 解读及其缓存尚未完成并随 PDF 线暂缓；相关论文页面仍缺真实语义检索或引用图谱。
- 论文聊天“读取全文”在部分下载、解析或异常场景可能无反馈或停留在加载状态，对应修复随 PDF 线暂缓。
- DeepSeek Key 由用户配置并存入设备安全存储；公开构建不包含共享 Key，清理普通业务数据不隐式删除 Key。
- 社区和私信仅保留未接入生产导航的实验代码；Hugging Face Blogs 后续作为社区文章来源，不进入论文频道。

---

## 3. 开发任务

### 3.1 论文数据、频道与阅读

客户端论文阅读只保留尚未完成的任务；服务端数据与推荐主线见下方 Phase 1–5。

| # | 任务 | 状态 | 说明 |
| --- | --- | --- | --- |
| 1 | 六问结构化 AI 解读与缓存 | 暂缓 | 保留现有 PDF 下载、提取、分块与页码能力；六问生成、版本化缓存、失败恢复和失效规则随 PDF 线后续排期 |
| 2 | AI 解读进入论文 ChatPaper 默认上下文 | 暂缓 | 六问结果有效时注入新建论文会话，不作为消息重复显示；依赖任务 1，随 PDF 线暂缓 |
| 3 | 相关论文语义检索 | 待开始 | 第一阶段使用标题、Abstract 与内容关键词召回，后续接入向量和引用图谱 |

#### 新主线：论文数据底座、服务与推荐系统

本阶段先完成只收录人工智能领域论文的数据底座、服务端查询能力，以及推荐 / 关注 / 最新三个频道的基础数据供给。长期推荐目标统一为 `Quality + Trend + Personalization`：从历史影响力中发现经典，从近期社区信号中发现趋势，再利用用户行为找到最适合个人的论文。

数据流：

```text
本地 arXiv 数据集/增量 ─┐
HF Daily Papers 增量 ───┼─> 原始快照 ─> 身份解析/去重 ─> AI 准入 ─> 元数据增强 ─> Paper Database
OpenAlex / Semantic Scholar / GitHub 增强 ─┘                                │
                                                                            ├─> Latest Index ─┐
                                                                            ├─> Candidate Pools ─> Recommendation Service
                                                                            └─> Channel Index ─┘
                                                                                                  ↓
                                                                                              Paper API
                                                                                                  ↓
                                                                                                Client
```

| 阶段 | 状态 | 主要交付 |
| --- | --- | --- |
| Phase 1：论文数据底座 | 待开始 | 导入本地 arXiv 数据并建立增量同步；镜像 HF Daily；同步 OpenAlex/Semantic Scholar/GitHub；AI 准入；`paper_id`、去重、统一字段、来源留痕与 Paper Database |
| Phase 2：基础 Feed API | 等待 Phase 1 | 推荐频道的 High Impact / Trending 候选池、基础质量/趋势分、时间分层、已读过滤、概率抽样与混排；最新频道日期回填；关注频道保持基础功能 |
| Phase 3：热点能力增强 | 后续阶段 | GitHub star velocity、citation velocity、Web Heat、LLM Trend Scout、24–72 小时 Trend Boost 与热点原因 |
| Phase 4：个性化推荐 | 后续阶段 | 行为日志、用户画像与论文向量、Personalized Pool、个性化排序、Diversity 与 Exploration |
| Phase 5：高级推荐系统 | 后续阶段 | 多路召回、Two-Tower、Learning to Rank、Reranker、序列推荐、实时兴趣更新与 A/B Test |

Phase 1 按以下依赖顺序拆分：

| # | 任务 | 完成条件 |
| --- | --- | --- |
| 1.1 | Paper schema 与原始快照契约 | 明确 `paper_id`、外部 ID、字段来源、可空值、时间语义、schema 版本和迁移策略 |
| 1.2 | HF Daily 镜像 PoC | A100 按日期增量保存原始/规范化数据、ETag 和游标；重跑幂等，断网/429 保留最后成功快照；Client 暂不切流 |
| 1.3 | arXiv 底库导入与增量 | 导入现有数据集，按规范时间和版本去重；建立 OAI/API 增量、AI 分类准入和失败恢复 |
| 1.4 | 身份解析与数据质量 | arXiv ID/DOI/OpenAlex ID 精确匹配可审计；低置信度模糊匹配、撤稿和异常值进入隔离/复核状态 |
| 1.5 | OpenAlex/Semantic Scholar/GitHub 增强 | 同步质量信号、Topics、Venue、DOI、影响引用与可靠仓库字段；各来源独立保存抓取时间、周期快照和缺失原因 |
| 1.6 | 索引与只读 Paper API | 建立 Latest/Channel/Candidate 索引，提供 `/api/v1` 详情和日期游标查询；随后再进入 Phase 2 推荐刷新接口 |

服务端逐步拆分为 `Data Pipeline`、`Paper Database`、`Recommendation Service`、`Paper API` 和 `Model Service`。抓取、清洗、跨源匹配、候选池生成和在线元数据查询主要使用 CPU；A100 为服务端 PDF/OCR、Embedding、主题分类、相似论文、reranker、摘要/翻译、Paper QA、用户兴趣向量和 LLM 热点分析等模型任务预留。数据、日志、索引和模型产物只落在 `/data2/fanjiahao/...`；每次安装依赖或下载数据前按服务器规范探测网络，禁止向 `/`、`/home`、`/data1` 或 `/data3` 落大数据。

客户端请求论文时，Paper API 不临时扇出访问 arXiv、OpenAlex、Semantic Scholar、Hugging Face 或 GitHub；所有第三方数据通过离线同步或后台增量任务提前写入本地数据库。这样才能稳定控制延迟、第三方限流、字段协议、推荐分数版本与离线重算。

**数据源与 AI 准入：**

- 本地 arXiv 数据集是论文主底库，首次导入后继续同步 arXiv 新发布/更新记录；它提供标题、摘要、作者、时间、arXiv ID/分类、PDF 和原文链接等基础字段。准入目录至少覆盖 `cs.AI`、`cs.LG`、`cs.CL`、`cs.CV`、`cs.RO`、`stat.ML`，其他分类经确认后版本化加入。
- Hugging Face Daily Papers 定时镜像到本地，用于补充最新频道、Trending Pool 与 HF 热度；它只是发现/策展来源，不覆盖 arXiv 的规范发布时间。
- OpenAlex 数据提前同步到 Paper Database，用于引用数、引用趋势、Topics/Concepts、Venue、DOI、AI 二次判断和历史高影响力筛选；Client 不直接访问 OpenAlex。
- Semantic Scholar 数据提前同步到 Paper Database，用于 `citationCount`、`influentialCitationCount`、`referenceCount`、引用图谱和后续相似论文召回；Client 不直接访问，也不与 OpenAlex 原始引用数相加。
- GitHub 只接受可靠的论文—仓库匹配，保存 `github_url`、`github_stars`、`github_forks`、`github_last_updated_at`、`github_stars_updated_at`；周期快照用于后续计算 stars 增速。
- 历史 arXiv 冷启动库同时满足 AI 准入和可配置影响力阈值；每日 arXiv/HF 增量只做 AI 准入，不因引用或 stars 尚低被淘汰。

**数据源接口、限流与许可：**

| 数据源 | 长期保留的契约 | 同步与风险边界 |
| --- | --- | --- |
| arXiv API / OAI-PMH | `published` 表示首个版本时间，`updated` 表示当前版本时间；公开排序只有 relevance/提交时间/更新时间，不提供可靠热度字段 | 大批量元数据优先 OAI；legacy API、OAI、RSS 合计最多每 3 秒 1 次且单连接。描述性元数据可保存，PDF/源文件仅在论文许可证允许时处理，并保留 arXiv 来源致谢。[API 手册](https://info.arxiv.org/help/api/user-manual.html)、[API 条款](https://info.arxiv.org/help/api/tou.html) |
| OpenAlex Works | 使用 `cited_by_count`、`counts_by_year`、`fwci`、`citation_normalized_percentile`、Topics/Concepts、Venue、DOI 和 `updated_date` | 作为默认学术质量增强，按预算配置 6–24 小时刷新；API Key 和预算只留服务端。OpenAlex 数据为 CC0，但推断字段仍需来源与抓取时间。[Works API](https://developers.openalex.org/api-reference/works)、[认证与计费](https://developers.openalex.org/guides/authentication) |
| Hugging Face Papers | Daily Papers 提供 AI 社区策展与近期热度，Trending 主要反映近期 GitHub star 活动；不等同于引用影响力 | 服务端低频同步、条件请求和失败回退；接口字段、限额和服务条款需持续监控，只保存功能所需元数据/信号，不默认镜像 PDF、媒体或外部代码。[Hub API](https://huggingface.co/docs/hub/en/api)、[限流](https://huggingface.co/docs/hub/en/rate-limits)、[服务条款](https://huggingface.co/terms-of-service) |
| Semantic Scholar | 使用 `citationCount`、`influentialCitationCount`、`referenceCount`、引用图谱和后续相似论文召回 | 作为 Phase 1 学术影响增强；Key 只留服务端。它与 OpenAlex 的引用覆盖不同，不能直接相加，只能分别归一化或分别展示。[Academic Graph API](https://api.semanticscholar.org/api-docs/graph)、[API 许可](https://www.semanticscholar.org/product/api/license) |
| Papers with Code（默认关闭） | 可提供 code、benchmark、SOTA 与论文—代码关系标签 | 不作为核心质量分。数据涉及 CC-BY-SA 与网站非商业条款，商业使用前必须单独审查署名、ShareAlike 和站点条款。[数据仓库](https://github.com/paperswithcode/paperswithcode-data)、[网站条款](https://paperswithcode.com/site/terms) |

Hugging Face 接口契约：

| 用途 | 接口 | 分页与边界 |
| --- | --- | --- |
| Daily Papers | `GET /api/daily_papers` | `p` 从 0 开始，`limit` 为 1–100；支持 `date=YYYY-MM-DD`、ISO `week`、`month`、`submitter`，以及 `sort=publishedAt|trending` |
| HF 当前索引 | `GET /api/papers` | 使用 cursor 与响应 `Link: rel="next"`；可以遍历 HF 当前可见索引，但不是全部 arXiv 的权威快照 |
| 搜索 | `GET /api/papers/search?q=...` | 仅作为未来搜索增强，不参与基础 Feed |
| 详情 | `GET /api/papers/{paperId}` | 可获取关联模型、数据集和 Space；禁止在信息流中逐篇扇出请求 |

上述接口以 [Hugging Face OpenAPI](https://huggingface.co/.well-known/openapi.json) 为当前契约。Daily 响应是“策展项 + 内层 `paper`”，而 `/api/papers` 是扁平论文对象，必须使用独立 DTO。Daily 内层基础字段为 ID、作者、标题、摘要、发布时间、upvotes 和 discussion ID；`submittedOnDailyAt`、提交者、GitHub、组织、AI 摘要/关键词、缩略图和评论等全部按可空字段解析，并忽略未知新增字段。

- `submittedOnDailyAt` 是 HF 入选时间；HF `publishedAt` 仅作列表回退；最新频道和年龄桶使用 arXiv 规范 `published`，版本变化使用 `updated`。
- HF upvotes、comments、GitHub stars 进入外部趋势信号，不能覆盖 Spark 本地点赞、评论、收藏或分享。
- 同步任务保存原始响应、请求参数、ETag、游标和最后成功快照；优先使用 `If-None-Match`，遇到 429 时读取 `RateLimit` 头并延迟重试，不能把某次实测额度写成常量。
- Hugging Face Blog Articles 属于社区文章；发现入口优先使用 [`/blog/feed.xml`](https://huggingface.co/blog/feed.xml) RSS。Hub OpenAPI 没有稳定的文章列表读取契约，禁止依赖 `/blog` DOM 作为生产接口。[Blog Articles](https://huggingface.co/docs/hub/blog-articles)

数据时间统一拆分：`source_updated_at` 表示来源自身更新时间（仅来源提供时填写），`fetched_at` 表示 Spark 实际抓取时间，`generated_at` 表示索引或推荐批次生成时间；三者不能混成一个 `updated_at`。

**论文身份与字段协议：**

- 每篇规范论文生成内部稳定 `paper_id`，并保存可空的 `arxiv_id`、`doi`、`openalex_id`、`semantic_scholar_id`、`huggingface_id` 和 `github_url`。
- 身份匹配按 `arXiv ID → DOI → OpenAlex/Semantic Scholar 外部 ID → 标题 + 作者模糊匹配` 依次进行；模糊匹配只产生候选和置信度，未达到阈值时保持独立并进入待核验队列，不能强行合并。
- 远程 DTO、原始快照、规范论文、推荐特征和 API DTO 分层；字段保存来源、抓取时间与匹配证据，信号快照可过期、可重算。
- `venue_name`、`venue_type`、`venue_year`、`venue_url`、`doi`、`affiliations`、`citation_count` 等字段没有可靠值时为 `null`。数值 `0` 只表示来源明确返回零，不能表示未知。
- GitHub 仓库不存在或未可靠匹配时，GitHub 对象为 `null`；存在时至少返回 URL、stars 和 stars 抓取时间，stars 允许为真实的 `0`。
- 外部引用、HF 热度和 GitHub stars 与用户本地点赞、收藏、评论、分享等互动指标分开存储，不能写入同一计数器。

**Client 迁移边界：**

- 当前 `PaperFeedQuery` 只表达 category/time/offset/limit，迁移时必须增加明确的 feed kind、provider 与服务端 cursor，不能继续假设所有远程目录都是 arXiv。
- 缓存键至少包含 provider、feed kind、sort、时间/策展窗口和 cursor/page；推荐、最新、主题及 arXiv 迁移期回退不得串用缓存页。
- remote/cache/seed 表达数据可用方式，arXiv/HF/Spark API 表达数据来源，两者必须分别建模。
- 外部质量/趋势信号使用独立 DTO、缓存和领域模型，不进入现有本地互动 metrics。
- 迁移期可以保留 arXiv 直连作为离线回退，但服务端响应与 arXiv 回退必须分别标记来源、分页语义和错误状态。

**频道行为：**

| 频道 | 候选与排序 | 筛选 |
| --- | --- | --- |
| 推荐 | 混合 High Impact Pool 与 Trending Pool，后续加入 Personalized Pool；按版本化推荐权重加权无放回抽样，不是固定 Top-N | 不支持用户筛选 |
| 关注 | 只返回用户已关注作者、主题、机构、会议等对象对应的论文；数据结构与论文卡片字段保持统一，但不继承推荐抽样 | 本阶段不做特殊改动 |
| 最新 | 合并 arXiv 最新论文与 HF Daily Papers，去重后按规范发布时间倒序；当日耗尽后由日期游标回填前一日，以此类推，不做高引或高 stars 筛选 | 固定最新优先 |
| 主题 | 按版本化 AI 主题目录查询 | 支持时间筛选，以及“最新 / 影响力”排序 |
| 会议 | 只收录具有可靠规范会议身份的论文 | 支持时间筛选，以及“最新 / 影响力”排序 |

推荐处理链：

```text
High Impact Pool ─┐
Trending Pool ────┼─> Ranking ─> Diversity Control ─> Time Bucketing ─> Read/Exposure Control ─> Probability Sampling ─> Feed
Personalized Pool ┘（Phase 4 加入）
```

**基础推荐模型：**

- High Impact Pool 负责提供经过时间或社区验证的重要论文。`QualityScore` 组合年龄归一化后的 citation count、不同时间窗的 citation velocity、GitHub stars、Venue 和其他长期质量信号，不能直接按累计引用数排序。
- Trending Pool 负责提供近期快速升温的新论文。`TrendScore` 组合 HF heat、GitHub star velocity、短期 citation velocity 和 freshness；近期论文不因累计引用较低被历史经典压制。
- 所有信号先按分布做对数化、分位数或同年龄段归一化，再进入版本化权重；缺失信号不冒充零，并通过可用信号重归一化避免没有仓库的论文被固定惩罚。
- Quality 与 Trend 分别计算、分别形成候选池，再按可配置比例混排。`RecommendationScore` 是一次刷新使用的抽样权重，不等同于 `QualityScore` 或 `TrendScore`；后续再加入 `UserPreferenceScore`、freshness、diversity 与 exploration。
- 不同领域和年龄窗口分别归一化；对引用、stars、upvotes 的极端值做 P99 截断或异常标记，对超新论文的速度分母设置平滑下限，避免单一暴涨信号吞掉候选池。
- 数据管道记录撤稿/更正状态、匹配审计和异常原因；被撤稿论文默认不进入推荐，低置信度或异常记录不参与正式评分。
- 推荐批次保留特征快照、权重版本和抽样种子，用于离线回放新旧论文比例、领域覆盖、缺失值偏差和排序变化；Client 展示来源明确的原始证据与抓取时间，而不是只有不可解释总分。

概念公式：

```text
QualityScore =
  w1 × CitationScore
+ w2 × CitationVelocity
+ w3 × GitHubScore
+ w4 × VenueScore
+ w5 × OtherQualitySignals

TrendScore =
  w1 × HFHeat
+ w2 × GitHubStarVelocity
+ w3 × ShortWindowCitationVelocity
+ w4 × Freshness
```

**时间结构与刷新：**

1. 推荐按规范发布时间进入互斥年龄桶。初版目标分布为 `0–1 年 40%`、`>1–3 年 30%`、`>3–5 年 15%`、`>5 年 15%`，全部服务端配置化。
2. 比例是跨多批次的长期分布目标；当请求量较小（例如 10 篇）无法精确表达 15% 时，采用滚动配额或随机舍入，候选不足时按版本化回补规则转移名额。
3. Client 每次刷新请求固定数量（初版可为 10）并提交有界的本地已读 ID 排除集；已读论文抽样权重固定为 `0`，仅曝光未读论文可衰减但不永久排除。
4. 服务端先完成候选生成、质量/趋势打分、时间分桶和已读过滤，再做概率采样及 High Impact / Trending 混排；同一批次不重复，并限制同一作者或同一主题连续占位。
5. 分数越高仅表示被抽中的概率越高，不要求严格降序；保留可配置随机探索，使刷新结果不完全固定。
6. 响应携带 schema/score 版本、抽样批次标识和可解释信号摘要；任何分数、池比例、年龄桶或回补规则都不得写死在 Client。

**Phase 3：实时热点发现：**

- `LLM Trend Scout` 通过 Web Search 从社交媒体、Reddit、Hacker News、GitHub、研究者博客、AI 社区、新闻和论文讨论站发现正在形成热度的候选论文。
- LLM 只负责发现趋势，候选必须经过 arXiv/DOI/OpenAlex/GitHub 身份核验后才能进入 Trending Pool，避免把产品、博客、同名论文或老论文重新讨论误判为新论文。
- 结构化保存 `web_heat_score`、`web_mentions`、`web_source_count`、`trend_detected_at`、`trend_reason`、`trend_topics`；Client 只需展示“Trending”或简化的近期升温原因。
- 可对核验后的实时热点施加 24–72 小时 `Trend Boost`，随后快速衰减，避免短期话题长期占据推荐流。

**Phase 4–5：个性化与高级推荐：**

- 显式信号包括点赞、收藏、评论、分享、关注与不感兴趣；隐式信号包括停留、快速划过、摘要/翻译/PDF/相关论文/GitHub/作者点击、搜索和重复访问。行为采集需有明确的隐私、同意、保留和删除边界。
- 个性化后形成 `Quality + Trend + Personalization` 三条核心信号，并加入 Freshness、Diversity 与 Exploration。初始可将 `60% 高相关 + 20% 相邻主题探索 + 10% 全局热点 + 10% 经典高影响力` 作为可配置实验，而不是固定产品承诺。
- Personalized Pool 可从用户画像、行为、关注关系、用户/论文 Embedding 生成；始终保留全局热点、相邻主题和经典论文，避免兴趣茧房。
- 数据规模和真实反馈成熟后，再从线性加权逐步演进到多路召回、Embedding Recall、Two-Tower、Learning to Rank、Reranker、行为序列模型、实时兴趣更新和 A/B Test。

```text
RecommendationScore =
  QualityComponent
+ TrendComponent
+ UserPreferenceComponent
+ FreshnessComponent
+ DiversityAndExplorationAdjustment
```

### 3.2 ChatPaper

| # | 任务 | 状态 | 说明 |
| --- | --- | --- | --- |
| 1 | 修复论文聊天“读取全文”异常反馈 | 暂缓 | 随 PDF 线暂缓；恢复时要求所有下载/解析失败路径复位 loading，并覆盖无 PDF、超时、HTTP 错误和解析异常测试 |
| 2 | 主聊天侧边追问（side chat） | 待开始 | 从主聊天当前状态 fork 临时会话，解决主线探索中的概念追问；不污染主聊天，退出即删除，交互与边界见 §4.3 |

### 3.3 我的

| # | 任务 | 状态 | 说明 |
| --- | --- | --- | --- |
| 1 | 收藏分组排序与批量移动 | 待开始 | 数据层已保留顺序能力；删除分组目前会一并移除组内收藏关系 |
| 2 | 个人研究数据导出 / 导入 / 备份恢复 | 待开始 | 定义可验证的导出格式、冲突处理和恢复失败反馈 |
| 3 | 用户侧迁移失败恢复 | 进行中 | 在现有占用统计、分类清理和版本迁移基础上，补齐显式恢复、损坏隔离结果和用户反馈 |

---

## 4. 设计规格参考

### 4.1 论文频道

#### 频道栏布局

```
推荐  关注  最新  人工智能  计算与语言  机器学习  ICML  ACL  ＋
```

- `推荐 / 关注 / 最新` 固定存在，不能删除
- 用户添加的主题和会议显示在后面
- 频道栏支持横向滚动；`＋` 固定在右侧，始终可见
- 每个频道独立保存浏览位置
- 点击论文后返回时仍在当前频道信息流
- 不再使用原来的领域筛选按钮

**会议频道**（保留官方缩写）：

```
AAAI   ACL    COLM   COLT   CoRL   CVPR
ECCV   EMNLP  ICCV   ICLR   ICML   IJCAI
INTERSPEECH  IWSLT  MICCAI  MLSYS  NAACL  NDSS
NeurIPS  OSDI  UAI  USENIX-Fast  USENIX-Sec
```

> **约束**：会议频道必须接入真实数据源后再进入正式版本，不能只提供空白 UI。

#### 筛选与排序

时间筛选只用于用户选择的主题频道和会议频道：

```
不限时间 / 最新发布日 / 最近 7 天 / 最近 30 天 / 选择日期 / 自定义时间范围
```

示例组合：`机器学习 + 最近 7 天`，`ACL + 2026 年`，`ICML + 2025 年`。
主题和会议频道均支持“最新 / 影响力”排序；会议数据还可按年份和 Track 进一步筛选。推荐频道不提供筛选；最新频道固定按规范发布时间倒序回填；关注频道本阶段保持现有行为。

#### 论文元数据字段

**arXiv 主题论文**必须具备：arXiv ID、标题、作者、Abstract、Subjects、Publish Time、更新时间、原始论文地址、PDF 地址。

Subjects 示例：
```
Machine Learning (cs.LG)
Artificial Intelligence (cs.AI)
Computation and Language (cs.CL)
```

**会议论文**必须具备：标题、作者、Abstract、会议名称、会议年份、Track 或论文类型、原始来源、PDF 地址。

Subject 使用结构化格式：
```
ACL 2026 · Long Paper
ICML 2026 · Oral
CVPR 2026 · Highlight
NeurIPS 2025 · Poster
```

**引用数约束**：
- 引用数暂不以不可靠数据出现在产品界面
- arXiv 本身不提供可靠引用数；未增强的数据不能显示成"被引 0"
- 本阶段由服务端通过 OpenAlex 可靠匹配后增强，并明确标记数据来源和更新时间；未匹配时为 `null`

**可空字段约束**：会议、Venue、GitHub 仓库、stars、引用数、DOI、单位及其他增强字段只有在来源可靠时返回；未知统一为 `null`。GitHub 仓库存在时 URL 与 stars 成组返回，并携带抓取时间；不以空字符串或伪造的 `0` 占位。Client 初期只展示 GitHub 仓库链接与 stars，forks 和更新时间先作为服务端特征保留。

### 4.2 论文内容页面

#### 六页结构

```
Abstract  摘要  关键词  作者  AI 解读  相关论文
```

- 标签采用内容宽度和横向滚动，不做六等分矩形布局
- 每次切换论文默认回到 `Abstract`

#### Abstract

- Markdown 和公式渲染；文本可选择；内容超出后滚动
- 不进行两端对齐；保持紧凑行距

#### 摘要（中文翻译）

界面只显示内容状态，不向用户暴露内部实现细节：

```
生成中文摘要
正在生成...
生成失败，点击重试
```

不显示「DeepSeek 中文翻译」「思考模式已关闭」「使用某某模型生成」等文案。

#### 关键词

关键词必须来自论文内容，不能把 `cs.AI`、`cs.LG` 当作关键词。arXiv Subjects 和内容关键词必须分开存储。

生成规则：
1. 使用标题和 Abstract 提取关键词
2. AI 解读完成后，可用 PDF 全文重新生成更准确的关键词
3. 每篇论文保存约 5–12 个关键词，按重要程度排序
4. 结果写入本地缓存

示例：`低秩适配`、`参数高效微调`、`冻结预训练权重`、`低秩矩阵分解`、`大语言模型`

#### 作者

当前只展示完整作者列表，不展示不可靠的单位占位。第一作者、通讯作者、单位、作者主页和同作者论文等待 OpenAlex、论文 PDF 或其他可靠来源增强后再加入。

#### AI 解读

当前状态：设计保留，生成与缓存实现随 PDF 线暂缓；恢复排期后按以下规格实施。

固定回答六个问题：
- Q1：这篇论文试图解决什么问题？
- Q2：有哪些相关研究？
- Q3：论文如何解决这个问题？
- Q4：论文做了哪些实验？
- Q5：有什么可以进一步探索的点？
- Q6：总结一下论文的主要内容。

初始状态不自动生成，用户点击后才执行：

```
生成 AI 解读
```

生成流程：
```
下载 PDF → 提取正文 → 清理页眉页脚和参考文献噪声
→ 按章节或长度分块 → 分块分析 → 汇总为六问结构化答案 → 保存到本地缓存
```

实现约束：
- DeepSeek 不直接上传 PDF，实现层先提取 PDF 文本，再分段发送给模型
- 缓存键至少包含：paperId、PDF 版本或文件哈希、提示词版本、模型版本、输出语言
- 论文更新或提示词结构改变后，判断旧缓存是否需要重新生成

#### AI 解读与 ChatPaper 的关系

AI 解读生成的六问答案作为论文 ChatPaper 会话的默认背景信息：

```
论文元数据 + Abstract + 关键词 + 六问 AI 解读
```

用户从论文页打开 AI 对话时：
- 自动关联当前论文；不需要重新粘贴论文信息
- AI 知道之前生成的六问答案；用户可继续追问实验、公式、局限性和相关工作
- 默认上下文不作为聊天消息重复显示

#### 相关论文

暂保留页面和空状态，真实检索后续实现。
未来检索条件：论文标题语义、内容关键词、Abstract 向量、Subjects、作者关系、引用关系。
第一阶段用"标题 + 关键词"语义检索，之后加入全文向量和引用图谱。

### 4.3 ChatPaper

#### ChatPaper 上下文边界（主聊天 / 论文聊天 / 派生缓存 / side chat）

四类上下文严格分离：

| 上下文 | 身份 | 内容来源 | 存储 |
| --- | --- | --- | --- |
| 主聊天 | `spark-main-ai-chat` 固定 id | 通用 systemPrompt，永不注入论文数据 | `chat_sessions.json` |
| 论文聊天 | contextId = 论文 id | 论文元数据 + Abstract + 有效缓存关键词；用户开启“读取全文”后追加按预算裁剪的 PDF 分块和页码引用 | `chat_sessions.json`；全文提取缓存为 `papers.pdf-extracts` |
| 论文派生缓存 | 论文级独立缓存 | 关键词 / 中文翻译 / 阅读状态；六问 AI 解读仍待实现 | `papers.*` 独立 schema |
| side chat（临时） | 从主聊天 fork 的临时 contextId，仅 side chat 模式期间存在 | 进入模式时的主聊天 systemPrompt + 消息历史快照（仅背景注入，只读） | 内存临时会话，退出模式即删；不写入 `chat_sessions.json` |

边界规则：

- 会话仓储只持久化聊天消息（ChatMessage）；派生数据不进入消息，只作为 systemPrompt 背景注入
- 主聊天永不注入论文派生数据；论文聊天只注入当前论文的派生数据
- 关键词只注入「已缓存且版本有效」的数据；arXiv Subjects 与内容关键词分开，Subjects 不冒充关键词
- 派生缓存失效（论文更新 / prompt 版本变化）后新会话不再使用旧缓存；历史会话消息保持不变
- 六问 AI 解读结果作为论文聊天默认背景依赖 §3.1 客户端任务 1，当前随 PDF 线暂缓；已有能力仅在用户主动开启“读取全文”后注入 PDF 分块
- side chat 从主聊天当前状态 fork，只读进入模式时的上下文与消息快照；追问不写入主聊天，退出模式即丢弃，不持久化、不进入会话列表

#### side chat 交互

目的：用户探索主线问题时随时弄清不熟悉的概念，同时不污染主聊天上下文。

- 入口：主聊天右上角虚线气泡图标；点击进入 side chat 模式，再次点击返回主聊天
- 模式提示：side chat 使用差异化主题；主标题追加「（临时聊天）」，明确当前处于临时会话
- 返回提示：切回主聊天时提示「临时聊天内容不会保存」，可勾选「不再显示」；该偏好可持久化，临时会话本身仍不保存
- fork 时机：每次进入都从主聊天当时的最新状态重新 fork；上一段临时会话在退出时已经丢弃

### 4.4 本地缓存清单

**当前单机阶段**，以下内容按需生成并本地缓存：

| 缓存项 | 触发时机 |
| --- | --- |
| 中文摘要 | 用户在摘要页触发 |
| 内容关键词 | 用户在关键词页触发；缓存有效时同时进入 ChatPaper 上下文 |
| 六问 AI 解读 | 随 PDF 线暂缓；恢复后由用户在 AI 解读页触发生成 |
| PDF 提取结果 | 论文聊天用户点击“读取全文”后下载、提取并缓存 |
| 论文 AI 会话 | 用户主动创建或从论文页打开 |
| side chat 返回提示偏好 | 用户勾选“不再显示”后持久化；临时会话内容仍不保存 |

所有能力按需生成，避免用户没有阅读意图时浪费 API 调用。

---

## 5. 后续边界

本节只记录不属于当前阶段开发任务的扩展边界；可执行任务以第 3 节为准。

### 5.1 服务端与数据闭环（论文 + ChatPaper）

- 用户登录；点赞、收藏、评论、关注与搜索历史同步；本地未同步操作队列
- DeepSeek 后端代理：安全保存 Key、额度、限流、会话云持久化与成本控制
- 论文级共享派生数据：中文摘要、关键词、AI 解读、PDF 解析与语义向量的云端缓存（同一版本论文只需生成一次）
- 论文数据服务的远期扩容、容灾、多节点部署与跨设备状态同步；本阶段的 A100 单机索引和查询接口见 §3.1

### 5.2 深度数据与推荐

- 推荐系统的热点、个性化和高级模型演进统一以 §3.1 Phase 3–5 为准，不在此处维护重复任务清单。
- 在 Phase 1 的 OpenAlex/Semantic Scholar 基础字段之上，后续再扩展完整引用图谱、结构化参考文献、向量检索和跨源质量校准。

### 5.3 社区与私信

前置依赖账号体系与服务端能力，就绪前保持 demo 代码不进入生产导航：

**社区**：补齐 application 层与仓储，用真实内容源和持久化替换演示数据；复用论文数据与互动模型，建立帖子、评论与论文讨论的关联。

**私信**：补齐 presentation 层、消息持久化与已读状态；明确私信、互动通知与系统消息的边界。

> **约束**：社区和私信进入生产导航时必须具备真实数据源与账号支撑，不以无行为入口出现。数据分层必须符合 `standards/code-structure.md`（补齐 application 层、仓储与 DTO 转换）。

---

## 6. 验收原则

### 论文

- 添加或移除频道后，频道栏和本地配置同步更新
- 每个频道的查询、分页、错误状态和浏览位置互不污染
- 同一论文从 arXiv、HF、OpenAlex、Semantic Scholar 或 GitHub 进入时复用稳定 `paper_id`；低置信度模糊匹配不会自动合并两篇论文
- Paper API 的在线查询不临时访问第三方服务；外部同步失败时保留最近成功快照，并能从幂等游标恢复
- 主题和会议频道的时间筛选与排序改变真实请求；离线时只使用匹配条件的缓存；推荐频道不显示筛选入口
- 最新频道只包含 AI 论文，合并 arXiv 与 HF Daily 后去重，按规范发布时间从当日连续回填到更早日期，且不做高引或高 stars 筛选
- 推荐频道在统计窗口内满足候选池混合与互斥年龄桶目标；同批次不重复，已读论文不会再次抽中，并限制同作者/同主题连续占位
- 未知会议、GitHub 仓库、stars、单位和引用数保持 `null`，不会显示为虚假数据；内容关键词不含仅用于分类的 arXiv 编号
- OpenAlex、Semantic Scholar、GitHub 与 HF 外部信号携带来源、抓取时间和版本；不同来源的引用数不会直接相加，本地互动计数不会被外部热度覆盖
- Phase 3 启用后，LLM/Web 候选必须先完成论文身份核验；Trend Boost 到期后衰减，不会成为永久质量分
- Phase 4 启用前，用户行为日志具备可理解的同意、保留、导出与删除边界，探索内容不会被个性化完全挤出
- 每篇论文默认进入 Abstract，六页切换无闪烁和高度跳变
- AI 解读只在用户触发后下载和处理 PDF，失败可重试且不会破坏旧缓存
- AI 解读完成后，新建论文聊天能读取六问结果作为默认上下文

### ChatPaper

- 输入区固定，不被消息内容或键盘异常挤压
- 流式过程与最终内容布局稳定，不在结束时整体跳变
- 代码块可复制，公式与 Markdown 失败时仍有可读纯文本降级
- 每个会话的上下文、思考开关和联网状态行为明确且可恢复
- side chat 不写入主聊天会话，追问前后主聊天消息与上下文完全一致；退出 side chat 模式后无残留会话

### 我的

- 所有数据管理操作明确展示影响范围并可验证结果
- 收藏、历史和稍后阅读在应用重启后保持一致
- 密钥只显示掩码，不进入日志、文档、源码或普通本地数据文件
- 未实现的账号或社区能力不以无行为入口出现在生产导航中

---

## 7. 发布关系

开发任务默认不绑定版本。只有当一组已经实现并验证的能力被选入发布候选后，才在 `releases/<version>/` 建立版本说明（README.md），记录发布范围、交付物与已知问题。

当前尚未正式发布，没有发布归档。达到发布标准后由 `/release` 在 `releases/<version>/` 建立版本说明。发布归档记录历史事实，不反向成为日常功能开发的唯一入口。
