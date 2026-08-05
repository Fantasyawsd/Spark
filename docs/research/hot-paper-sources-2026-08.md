# 热门论文筛选与数据源可行性研究

> 研究日期：2026-08-04
> 研究范围：arXiv API/OAI、OpenAlex、Semantic Scholar、Hugging Face Daily Papers/Trending、Papers with Code；重点面向 PaperFlow 当前“无自有后端、Flutter 客户端直连公开接口”的约束。
> 结论性质：文档中的“事实”均链接到数据源官方文档、官方页面或官方代码仓库；“建议 / 判断”是基于这些事实对 PaperFlow 的工程取舍。

## 1. 结论先行

### 1.1 不要把 arXiv 当作“热门度数据源”

**事实：** arXiv API 的公开排序参数是 `relevance`、`lastUpdatedDate`、`submittedDate`，返回的 Atom 元数据包括标题、摘要、作者、分类、`published`、`updated` 等；官方文档没有公开浏览量、下载量、点赞量、引用量或统一“热度分数”字段。`published` 表示首个版本提交并处理的时间，`updated` 表示当前版本提交并处理的时间。来源：[arXiv API User's Manual](https://info.arxiv.org/help/api/user-manual.html)。

**判断：** arXiv 很适合做 PaperFlow 的“最新候选池”和规范元数据主源，但不能单独回答“哪些论文热门”。`relevance` 也不是热度，它是搜索相关性排序。

### 1.2 当前最适合 PaperFlow 的组合

1. **候选池 / 论文主记录：arXiv**：按分类和时间取最近 30～90 天论文。
2. **学术影响信号：OpenAlex**：优先使用 `cited_by_count`、`counts_by_year`、`fwci`、`citation_normalized_percentile`，并保存 `updated_date` 和抓取时间。
3. **影响力交叉信号：Semantic Scholar**：在服务端或定时聚合任务中补充 `citationCount`、`influentialCitationCount`；不建议把私有 API Key 放进 Flutter 包。
4. **AI 社区信号：Hugging Face Daily Papers/Trending**：只作为 AI 子领域的社区 / 代码热度信号，不作为全学科的学术影响力替代。
5. **代码与基准信号：Papers with Code**：只作为“有代码 / 有 benchmark / 有 SOTA 记录”的增强标签；不建议作为核心热门排序源，原因是接口、站点运营和商业使用许可风险更高。

**推荐落地形态：** 如果“无后端”是硬约束，先做一个**静态定时聚合文件**（例如每 6～12 小时生成一次 `hot-papers.json`，放在静态托管上），而不是让每个 Flutter 客户端分别扇出请求多个第三方接口。它不是完整业务后端，但能隐藏 API Key、固定全局排序、减少重复请求和限流风险。后续做个性化时，客户端再对这份候选列表做本地重排，或将重排迁移到正式后端。

---

## 2. 数据源逐项研究

## 2.1 arXiv API / OAI-PMH

### 官方能力

| 项目 | 事实 | 对 PaperFlow 的含义 |
| --- | --- | --- |
| API 返回格式 | arXiv API 返回 Atom 1.0；官方示例包含 `id`、`published`、`updated`、`title`、`summary`、作者、评论、期刊引用和分类等字段。来源：[API Basics](https://info.arxiv.org/help/api/basics.html)、[User's Manual](https://info.arxiv.org/help/api/user-manual.html)。 | 可以继续作为论文主记录和最新频道的数据源。 |
| 首次提交与版本更新 | `published` 是首个版本提交并处理时间；`updated` 是当前版本提交并处理时间；当存在 v2、v3 时两者不同。来源：[User's Manual](https://info.arxiv.org/help/api/user-manual.html)。 | PaperFlow 应保留两个时间语义，不能把 `updated` 当作“首次发表日”。 |
| 搜索排序 | API 的 `sortBy` 只有 `relevance`、`lastUpdatedDate`、`submittedDate`，`sortOrder` 支持升序和降序。来源：[User's Manual](https://info.arxiv.org/help/api/user-manual.html)。 | 没有公开的官方热度排序参数；不能从 API 排序结果推断热度。 |
| OAI 元数据 | OAI-PMH 只暴露每篇文章的最新版本；`arXiv` 格式含最新版本元数据，`arXivRaw` 可包含历史版本；`datestamp` 是记录最后修改时间，不等于原始提交或替换时间。来源：[arXiv OAI](https://info.arxiv.org/help/oa/index.html)。 | 做增量同步时可使用 OAI `datestamp`，但“某日首次提交”仍应使用 arXiv API 的 `published` / 版本历史语义。 |
| 更新节奏 | arXiv 官方说明新论文每日接收；OAI 元数据在论文宣布后提供，通常为美国东部时间周日至周四约 22:30，日间也可能有少量元数据变化。API 文档还说明生产查询结果按日变化，应缓存同一查询。来源：[arXiv OAI](https://info.arxiv.org/help/oa/index.html)、[User's Manual](https://info.arxiv.org/help/api/user-manual.html)。 | “最新”可以按日刷新；不需要每次打开页面都重新拉取同一个查询。 |
| 访问限制 | legacy API、OAI-PMH、RSS 合计不应超过每 3 秒 1 次，并限制为单连接；大批量元数据收集应优先考虑 OAI-PMH。来源：[Terms of Use for arXiv APIs](https://info.arxiv.org/help/api/tou.html)、[User's Manual](https://info.arxiv.org/help/api/user-manual.html)。 | Flutter 端必须做请求队列、缓存和退避，不能在多个频道并行疯狂翻页。 |
| 许可与内容 | arXiv 允许获取、存储、转换和分享描述性元数据；但除非得到版权持有人许可或论文提交许可证允许，不得在自己的服务器存储和提供 arXiv PDF、源文件或其他内容。来源：[Terms of Use for arXiv APIs](https://info.arxiv.org/help/api/tou.html)。 | PaperFlow 应保存元数据和 arXiv 链接，PDF 继续跳转或按论文许可证处理；不要把 PDF 镜像进静态聚合物。 |
| 品牌与致谢 | arXiv 要求 API 使用者阅读 API 条款，并在产品中使用指定致谢语；不得以名称、Logo、网址或配色暗示 arXiv 背书。来源：[arXiv API Access](https://info.arxiv.org/help/api/index.html)、[Permissions and Reuse](https://info.arxiv.org/help/license/reuse.html)。 | 正式产品需要保留来源标注，UI 不应设计成 arXiv 官方客户端。 |

### 是否提供热度字段？

**结论：没有可依赖的官方热度字段。** 这里的“没有”是指公开 API/OAI 文档没有列出浏览、下载、点赞、收藏、引用或统一 popularity 指标；官方排序字段也只有相关性和时间。arXiv 页面本身可能存在站点统计或其他展示，但它们不是 API/OAI 的稳定热度契约，不能作为 PaperFlow 的核心排序输入。来源：[API User's Manual](https://info.arxiv.org/help/api/user-manual.html)、[arXiv OAI](https://info.arxiv.org/help/oa/index.html)。

### 适合的角色

- **主源：强。** 负责 arXiv ID、标题、作者、摘要、分类、版本和链接。
- **热门排序：弱。** 只能提供年龄、分类和版本更新时间，不能提供外部受欢迎程度。
- **新鲜度：强。** 日级数据足够支撑“arXiv 每日更新”。
- **客户端直连：可行，但要缓存。** API 公开、无需为每个用户发放私钥；但必须尊重 3 秒间隔和每日缓存建议。

---

## 2.2 OpenAlex

### 官方能力

| 项目 | 事实 | 对 PaperFlow 的含义 |
| --- | --- | --- |
| 作品字段 | Works API 返回 `cited_by_count`、`fwci`、`citation_normalized_percentile`、`cited_by_percentile_year`、`counts_by_year`、`created_date`、`updated_date` 等字段。来源：[Get a single work](https://developers.openalex.org/api-reference/works/get-a-single-work)、[List works](https://developers.openalex.org/api-reference/works/list-works)。 | OpenAlex 是当前最适合做“学术影响”增强的主候选源。 |
| 引用的含义 | `cited_by_count` 是 OpenAlex 找到其他作品参考文献并成功匹配到该作品的次数；数据来自 Crossref、PubMed 等记录，也可能从开放获取 PDF 抽取参考文献。来源：[Where does your citation information come from?](https://help.openalex.org/hc/en-us/articles/31459794276759-Where-does-your-citation-information-come-from)。 | 这是可解释的引用信号，但不是阅读量，也不是实时社区热度；不同学科覆盖和引用习惯仍会产生偏差。 |
| 年度引用 | `counts_by_year` 提供最近十年的年度 `cited_by_count`。来源：[Get a single work](https://developers.openalex.org/api-reference/works/get-a-single-work)。 | 可构造近年引用速度或年龄归一化引用，不要只按总引用排序。 |
| 查询与排序 | `/works` 支持按 `cited_by_count` 排序，也支持按出版日期排序；可以按出版日期、类型、`cited_by_count` 等字段过滤。来源：[List works](https://developers.openalex.org/api-reference/works/list-works)、[Sort](https://developers.openalex.org/guides/sort)、[Filter](https://developers.openalex.org/guides/filtering)。 | 可以在窗口内先取候选，再按引用与新鲜度重排；不需要下载完整数据集。 |
| 单条查询与批量匹配 | 单个实体查询免费；外部 ID 查找支持 DOI、ORCID、ROR、PMID 等形式。来源：[Get Singleton](https://developers.openalex.org/guides/get)。 | DOI 优先做映射；arXiv 论文无 DOI 时需要标题 / 作者 / 年份匹配，并保存匹配置信度，避免把同名论文错误合并。 |
| API 价格 / 限额 | OpenAlex 开发者文档说明免费 API Key 每日有 1 美元免费用量，并按操作类型计费；列出的示例包括列表、搜索、单条查询和 PDF 内容下载。来源：[Authentication & Pricing](https://developers.openalex.org/guides/authentication)。 | 不应把一个公开 Key 固化在所有客户端中；无后端直连只适合少量、强缓存、低频请求。 |
| 数据开放许可 | OpenAlex 官方说明完整数据集采用 CC0，可自由使用和分发。来源：[OpenAlex Developers overview](https://developers.openalex.org/)、[Pricing](https://help.openalex.org/hc/en-us/articles/24397762024087-Pricing)。 | 元数据许可风险低于 PWC / Semantic Scholar，但仍应保留来源与抓取时间，避免把 OpenAlex 的推断字段伪装成原始事实。 |
| 数据更新 | OpenAlex 官方帮助页称数据库随新作品和新记录“按小时”演进；同时官方定价页称免费快照按月发布、付费方案可通过 API 每小时同步；开发者下载页又写到公开快照为季度更新、付费计划有更高频快照。来源：[How does OpenAlex work?](https://help.openalex.org/hc/en-us/articles/28932712154391-How-does-OpenAlex-work)、[Pricing](https://help.openalex.org/hc/en-us/articles/24397762024087-Pricing)、[Data downloads overview](https://developers.openalex.org/download/overview)。 | 官方页面存在更新频率口径不完全一致的情况。对 PaperFlow 的安全结论是：热榜应使用 REST API 并记录 `fetchedAt`，不能把免费快照当作实时源；具体预算和刷新承诺上线前应以账号控制台 / 当前套餐为准。 |

### OpenAlex 的 `cited_by_count` 是否足够？

**不够。** `cited_by_count` 适合衡量累积影响，但对新论文存在年龄偏差：老论文有更多累积时间，热门新论文可能还没有足够引用。OpenAlex 同时提供 `counts_by_year`、`fwci` 和年度百分位等字段，因此推荐组合总引用、近年速度和年龄 / 学科归一化信号。来源：[Get a single work](https://developers.openalex.org/api-reference/works/get-a-single-work)、[Works overview](https://developers.openalex.org/api-reference/works)。

### 适合的角色

- **学术热度主信号：强。** 适合做“被学术界引用的热门”。
- **实时性：中到强。** REST API 可用于新鲜数据；免费快照不适合实时榜单。
- **客户端直连：有限可行。** 公开 Key 会暴露在客户端；没有服务端聚合时只能做少量按需查询和本地缓存。
- **许可：低风险。** CC0 是明显优势。

---

## 2.3 Semantic Scholar API

### 官方能力

| 项目 | 事实 | 对 PaperFlow 的含义 |
| --- | --- | --- |
| 论文引用字段 | Paper 数据可请求 `citationCount`、`referenceCount`、`influentialCitationCount` 等字段。来源：[Academic Graph API](https://api.semanticscholar.org/api-docs/graph)、[API tutorial](https://www.semanticscholar.org/product/api/tutorial)。 | `citationCount` 可做总引用，`influentialCitationCount` 可做“产生较大影响的引用”信号；两者都应标注来源和抓取时间。 |
| 影响引用定义 | Semantic Scholar 官方教程说明 `influentialCitationCount` 记录论文对其他论文产生较大影响的引用次数。来源：[API tutorial](https://www.semanticscholar.org/product/api/tutorial)。 | 比单纯总引用更接近“影响力”，但不能把它解释成用户热度或阅读量。 |
| 搜索与排序 | Bulk paper search 支持按 `publicationDate`、`citationCount` 排序，并支持 `publicationDateOrYear`、`minCitationCount` 等过滤；单次请求返回字段由 `fields` 控制。来源：[Academic Graph API](https://api.semanticscholar.org/api-docs/graph)。 | 可以在服务端一次批量取候选，避免逐篇请求；应只请求需要的字段。 |
| 推荐 API | Semantic Scholar 另有 Recommendations API，可根据正 / 负样本论文返回相似论文；这属于“相关性 / 个性化推荐”能力，不是公开的热门榜单。来源：[Recommendations API](https://api.semanticscholar.org/api-docs/recommendations)。 | 以后做个性化时可评估，但当前“热门”频道不应把相似论文接口当作热度排序。 |
| 未认证限流 | Semantic Scholar 官方产品页说明大多数端点可不认证，但未认证请求共享公共限额，繁忙时还可能被进一步限流。来源：[Semantic Scholar API overview](https://www.semanticscholar.org/product/api)。 | 依赖所有用户直接匿名请求会有不确定性。 |
| API Key 限流 | 官方产品页与教程说明，API Key 的入门限额是所有端点约 1 RPS；个别情况下经过审核可能提高。来源：[Semantic Scholar API overview](https://www.semanticscholar.org/product/api)、[API tutorial](https://www.semanticscholar.org/product/api/tutorial)。 | 一个客户端请求链路不能批量并发打满 API；应使用 batch / bulk、队列、指数退避和本地缓存。 |
| Key 安全 | API Key 通过 `x-api-key` 请求头传递；官方教程要求生产环境安全处理 Key，API 许可协议禁止把 Key 提供给无授权人员。来源：[Academic Graph API](https://api.semanticscholar.org/api-docs/graph)、[API License Agreement](https://www.semanticscholar.org/product/api/license)。 | 不能把 PaperFlow 团队 Key 编进 APK；如果没有后端，只能降低使用范围，或让用户自行配置自己的 Key。 |
| 数据更新 | Semantic Scholar 产品页将 Academic Graph 描述为持续更新的语料库，并提供 API 状态页。来源：[Semantic Scholar API overview](https://www.semanticscholar.org/product/api)、[API status](https://status.api.semanticscholar.org/)。 | 可作为日级或更低频的增强数据源，但不要对引用计数做分钟级实时承诺。 |

### Semantic Scholar 与 OpenAlex 如何取舍？

- OpenAlex 的公开数据许可和批量 / 单条 API 更适合做 PaperFlow 的**默认学术影响层**。[OpenAlex Pricing](https://help.openalex.org/hc/en-us/articles/24397762024087-Pricing)
- Semantic Scholar 的 `influentialCitationCount` 和论文图谱适合做**交叉验证或影响力增强层**，但 API Key、限流和许可条款使其不适合当前 Flutter 客户端作为主链路。[Semantic Scholar API tutorial](https://www.semanticscholar.org/product/api/tutorial)、[API License Agreement](https://www.semanticscholar.org/product/api/license)
- 不要把两个来源的引用数直接相加：覆盖范围、去重、更新时间和匹配规则不同。更稳妥的做法是分别标准化为分位数，再加权；界面显示时只显示来源明确的一项或分别展示。

---

## 2.4 Hugging Face Daily Papers / Trending

### 官方页面和 API 现状

| 项目 | 事实 | 对 PaperFlow 的含义 |
| --- | --- | --- |
| Trending 页面 | 官方页面提供 Daily / Weekly / Monthly 视图，展示论文的 Upvote、GitHub 等社区信号。来源：[Hugging Face Trending Papers](https://huggingface.co/papers/trending)。 | 可以作为 AI 社区热度的可见信号，但它不是全学科引用数据库。 |
| Trending 排名依据 | Hugging Face 官方 changelog 说明 Trending Papers 按近期 GitHub star 活动排序。来源：[Trending Papers changelog](https://huggingface.co/changelog/trending-papers)。 | “GitHub stars”更接近代码传播 / 开发者关注度，不应命名为学术引用影响。 |
| Daily Papers 的生成方式 | Hugging Face 官方博客说明 Daily Papers 由 AK 和研究社区筛选 / 提交，并提供 upvote、评论、作者认领等社区功能。来源：[Hugging Face blog source](https://github.com/huggingface/blog/blob/main/daily-papers.md)。 | 它是“社区策展 + AI 研究热点”，不是机器可解释的、全量无偏的论文排名。 |
| 官方 CLI | `huggingface_hub` 官方 CLI 提供 `hf papers ls`、`hf papers info`、`hf papers search`；示例支持 `--sort=trending`、按日期 / 周 / 月查询，并可 JSON 输出。来源：[Hugging Face CLI guide](https://huggingface.co/docs/huggingface_hub/en/guides/cli)。 | 即使不直接依赖网页 DOM，也有一手 CLI / API 线索可供定时任务使用。 |
| 页面数据 API | Hugging Face 官方组织维护的 Papers skill 文档记录了 `GET /api/daily_papers`、`GET /api/papers`、`GET /api/papers/search`，并列出日期、周、月、`trending`、分页和 JSON 返回等参数。来源：[huggingface/skills — huggingface-papers](https://github.com/huggingface/skills/blob/main/skills/huggingface-papers/SKILL.md)。 | 存在可调用的第一方接口，但主 Hub API 文档没有把 Daily Papers 作为长期稳定业务契约单独承诺；应把它视为可用但需监控变更的接口。 |
| 限流 | Hugging Face Hub 官方文档说明 Hub API 和所有网页请求均受 HF-wide rate limits 约束，具体桶和限制会变化。来源：[Hub API endpoints](https://huggingface.co/docs/hub/en/api)、[Hub rate limits](https://huggingface.co/docs/hub/rate-limits)。 | 适合低频定时聚合，不适合每个客户端每次进入首页都直接请求。 |

### 适合的角色

- **AI 社区热度：中到强。** 对“近期有代码、GitHub 传播、社区讨论”的论文尤其有用。
- **全学科热门：弱。** Daily Papers / Trending 的覆盖和策展集中在 AI 研究场景。
- **接口稳定性：中。** 页面稳定可见，API/CLI 可用，但 Daily Papers API 需要监控字段和路径变化。
- **成本：低。** 公开页面 / API 通常可直接访问，但受 Hub 限流和服务条款约束。
- **许可风险：中。** Hugging Face 页面包含社区提交、社区投票和外部代码链接；只保存论文 ID、分数、来源链接和抓取时间，避免未经核验地镜像摘要、代码或 PDF。具体商业再发布范围应审阅 [Hugging Face Terms of Service](https://huggingface.co/terms-of-service) 和相关内容来源的许可证。

---

## 2.5 Papers with Code

### 官方接口与数据

| 项目 | 事实 | 对 PaperFlow 的含义 |
| --- | --- | --- |
| 官方 API 客户端 | Papers with Code 官方 GitHub 组织维护 `paperswithcode-client`，README 将其描述为 paperswithcode.com 的读写 API 客户端；示例可以直接列出论文，写入模式需要 API token。来源：[paperswithcode-client](https://github.com/paperswithcode/paperswithcode-client)。 | 存在官方可用接口 / 客户端，但需要把它视作第三方社区数据集成，而不是学术引用基础设施。 |
| 可提供的数据 | 官方客户端 README 覆盖 papers、datasets、methods、evaluation tables 等模型；官方数据仓库提供论文摘要、论文-代码链接、评测表、方法和数据集下载。来源：[paperswithcode-client](https://github.com/paperswithcode/paperswithcode-client)、[paperswithcode-data](https://github.com/paperswithcode/paperswithcode-data)。 | 适合抽取“有代码”“关联 benchmark”“有 SOTA 记录”等结构化标签。 |
| 数据刷新 | 官方数据仓库 README 说明数据目前按日重新生成。来源：[paperswithcode-data](https://github.com/paperswithcode/paperswithcode-data)。 | 若继续使用，应按日或更低频同步，不要假设分钟级新鲜度。 |
| 数据许可 | Papers with Code 官方 About 页面说明网站内容采用 CC-BY-SA；官方数据仓库 README 同样标注 CC-BY-SA。来源：[About Papers with Code](https://paperswithcode.com/about)、[paperswithcode-data](https://github.com/paperswithcode/paperswithcode-data)。 | 如果将数据复制到 PaperFlow 的静态 JSON 或数据库，需要保留署名、许可证和相应的 ShareAlike 义务；不能把它当作“无条件公有领域数据”。 |
| 网站条款 | 官方 Terms of Use 写明网站面向个人、非商业和信息用途；这与 PaperFlow 未来是否商业化存在潜在冲突。来源：[Papers with Code Terms](https://paperswithcode.com/site/terms)。 | 在没有获得明确许可前，不建议把 PWC 数据作为商业产品的核心依赖；优先只存最小化标签并链接回原站，必要时做法律审查。 |

### 适合的角色

- **代码 / benchmark 信号：中。** 对 AI 论文发现很有价值，但它测量的是代码和基准生态，不等于学术热度。
- **全学科热门：弱。** 数据范围和产品定位主要围绕机器学习。
- **接口与运营风险：中到高。** 官方客户端和数据仓库可用，但不应假设其提供与 OpenAlex 类似的长期 API SLA；上线前要做健康检查和失败回退。
- **许可风险：高于 OpenAlex。** CC-BY-SA、网站非商业条款和社区贡献来源需要单独处理。

---

## 3. PaperFlow 推荐架构

## 3.1 目标与非目标

### 目标

- “推荐”首期表达为**热门 / 值得关注**，而不是个性化推荐。
- “最新”保持为 arXiv 每日新论文，使用首个版本时间而不是版本更新时间。
- 热门排序可解释：用户能看到“学术引用”“影响力引用”“社区代码热度”等来源。
- 外部字段失效、限流或匹配失败时，仍能展示 arXiv 基础论文流。

### 非目标

- 不把 arXiv 的搜索相关性当作热度。
- 不把 OpenAlex / Semantic Scholar 的引用数相加。
- 不把 HF upvote、GitHub stars、PWC benchmark 记录混称为“引用量”。
- 不在 Flutter 包内内置团队级 OpenAlex / Semantic Scholar 私钥。
- 不在客户端镜像第三方 PDF、代码仓库或完整社区数据集。

## 3.2 推荐的数据流

```text
arXiv API/OAI
    │  论文主记录、首发日期、分类、版本
    ▼
候选池构建（按 cs.* / 时间窗口 / 去重）
    │
    ├── OpenAlex：引用、年度引用、FWCI、百分位
    ├── Semantic Scholar：总引用、影响引用（可选）
    ├── HF：upvote、GitHub star / trending（AI 可选）
    └── PWC：code / benchmark / SOTA 标签（AI 可选）
    ▼
标准化热度信号（带 source、fetchedAt、matchConfidence）
    ▼
分领域、分时间窗归一化
    ▼
热门榜单 JSON / 本地缓存
    ▼
Flutter 展示；未来再叠加用户兴趣重排
```

### 建议的数据契约

外部数据不要直接写进 `Paper` 领域实体，建议增加独立的热度信号模型（名称可按项目现有约定调整）：

```text
PaperPopularitySignal
- paperId / arxivId
- source: openAlex | semanticScholar | huggingFace | papersWithCode
- sourcePaperId
- scoreType: citation | influentialCitation | githubStars | upvotes | code | benchmark
- rawValue
- normalizedValue
- fetchedAt
- sourceUpdatedAt（若源提供）
- matchConfidence
- unavailableReason
```

**判断：** 这样可以把“论文主数据”和“会随外部源变化的热度数据”分层，后续个性化推荐只需要消费标准化信号，不必重写 arXiv 适配器。

## 3.3 无后端阶段的两种方案

### 方案 A：严格客户端直连

**做法：** Flutter 直接调用 arXiv；对用户当前看到的少量论文按需调用 OpenAlex / Semantic Scholar；HF / PWC 只在打开详情页或 AI 频道时调用。

**优点：** 不需要部署任务；实现快；可以复用当前客户端网络层和缓存。

**缺点：**

- 每个用户重复请求同一篇论文，第三方总流量随用户数线性增长。
- Semantic Scholar API Key 无法安全放进 APK；OpenAlex Key 即便不是传统机密也会暴露预算。
- 不同用户因命中缓存、限流和匹配成功率不同，看到的“热门”可能不一致。
- 客户端不能稳定地取全量候选并完成跨来源排序。

**结论：** 只适合作为短期实验或详情页增强，不适合作为正式全局“热门频道”的长期架构。

### 方案 B：静态定时聚合（推荐）

**做法：** 使用 GitHub Actions、Cloudflare Worker Cron 或其他轻量定时任务，每 6～12 小时执行：

1. 从 arXiv 拉最近 30～90 天的目标分类候选。
2. 按 DOI、arXiv ID 或标题 / 作者匹配 OpenAlex；只对候选 Top N 请求 Semantic Scholar。
3. 对 AI 子集补充 HF Trending / Daily Papers；需要 code / benchmark 标签时再补充 PWC。
4. 写入带版本号、`generatedAt`、每条数据源 `fetchedAt` 的 `hot-papers.json`。
5. Flutter 只拉一个静态 JSON，并保留上一次成功版本作离线回退。

**优点：**

- API Key 不进客户端。
- 全局榜单稳定，所有用户看到相同的基础排序。
- 可以统一去重、归一化、限流、重试和错误回退。
- 以后加入个性化时，客户端可以在候选 Top 100 上本地重排；真正个性化再迁移到服务端。

**代价：** 需要一个很小的定时执行和静态托管位置；它不是完整后端，但已经是“集中聚合层”。

**推荐：** PaperFlow 当前最适合采用方案 B；论文 PDF、摘要和阅读状态仍可按现有方式直连 / 本地缓存，不需要一次性建设完整账号后端。

---

## 4. 推荐评分公式

## 4.1 先区分“热门”与“新锐”

只做一个总分会把老论文的累计引用和新论文的短期热度混在一起。建议先定义两个榜单分数：

- `evergreenHotScore`：偏长期学术影响，窗口 24～60 个月。
- `risingScore`：偏最近 30～180 天的增长和社区讨论。

首页“推荐”可以按 `70% rising + 30% evergreen` 取混排，并设置每个分类的最低配额，避免 cs.AI 或某个大领域完全挤占全部列表。

## 4.2 标准化规则

对每个 arXiv 分类或领域、每个时间窗口单独计算分位数，避免直接比较不同学科的原始引用量：

```text
pct(x, pool) = x 在同领域同时间窗候选池中的分位数，范围 [0, 1]
logCount(x) = log(1 + max(x, 0))
```

**原因：** OpenAlex 和 Semantic Scholar 的原始引用数都是累积计数；分位数 + `log1p` 可以减少极大值对榜单的支配。`fwci` 和 citation percentile 可作为归一化信号，来源字段见 [OpenAlex Works API](https://developers.openalex.org/api-reference/works)；这是 PaperFlow 的排序设计建议，不是数据源官方评分公式。

## 4.3 可上线的第一版公式

对候选论文 `p`：

```text
C = pct(log1p(OpenAlex.cited_by_count))
V = pct(log1p(OpenAlex.recentCitationCount / max(ageYears, 1)))
I = pct(log1p(SemanticScholar.influentialCitationCount))
F = pct(log1p(OpenAlex.fwci)) 或 pct(OpenAlex.citation_normalized_percentile.value)
U = pct(log1p(HuggingFace.upvotes))                 # 可选
G = pct(log1p(HuggingFace.githubStars))             # 可选
K = 1 if PWC 有可信 code / benchmark 关联，否则 0 # 可选
R = exp(-ageDays / 90)

base = available_weighted_mean(
  0.25 * C,
  0.20 * V,
  0.20 * I,
  0.20 * F,
  0.10 * U,
  0.05 * G
)

risingScore = 100 * (0.80 * base + 0.20 * R)
evergreenHotScore = 100 * available_weighted_mean(
  0.45 * C,
  0.25 * F,
  0.20 * I,
  0.10 * codeOrBenchmarkBonus(K)
)
finalScore = 0.70 * risingScore + 0.30 * evergreenHotScore
```

### 公式实现注意事项

1. **缺失值不能当 0 分。** 如果某论文没有 Semantic Scholar 匹配或没有 HF 记录，应从 `available_weighted_mean` 中移除该项并重新归一化；否则会系统性惩罚较新、较冷门或非 AI 论文。
2. **OpenAlex 与 Semantic Scholar 不相加。** 两者分别取分位数后作为不同特征；保留 `source` 和 `fetchedAt`。
3. **引用速度要有年龄保护。** 对 30 天内论文，`recentCitationCount / ageYears` 容易爆炸，应设置最小年龄、平滑项或直接使用分位数截断，例如 `max(ageYears, 0.25)` 并限制在领域候选池 P99。
4. **HF / PWC 只给小权重。** 它们对 AI 开发者圈很有解释力，但不是全学科的统一学术标准；建议总权重不超过 15%～20%。
5. **展示原始证据。** 卡片可以显示“OpenAlex 引用 123（抓取于某日）”“Semantic Scholar 影响引用 12”“HF GitHub stars 4.2k”，不要只显示一个无法解释的 `hotScore`。
6. **反作弊与异常值。** 对单日暴涨的 GitHub stars、投票或引用数据做 P99 截断、指数退避刷新和异常标记，不让单一信号瞬间吞掉整个榜单。
7. **分领域配额。** 先在 `cs.AI`、`cs.CL`、`cs.CV`、`cs.LG` 等分类内计算，再做全局混排；否则热门领域的体量优势会成为“热门”的唯一来源。

## 4.4 如果第一阶段只能接一个热度源

**推荐 OpenAlex，而不是 Semantic Scholar。**

理由是：

- OpenAlex 提供总引用、年度引用、FWCI、引用百分位和 `updated_date`，可构造更完整的年龄 / 领域归一化评分。[OpenAlex Works API](https://developers.openalex.org/api-reference/works)
- OpenAlex 完整数据采用 CC0，许可路径更清晰。[OpenAlex Pricing](https://help.openalex.org/hc/en-us/articles/24397762024087-Pricing)
- Semantic Scholar 的 `influentialCitationCount` 很有价值，但官方 API Key 和限流约束更适合作为聚合层的增强信号。[Semantic Scholar API overview](https://www.semanticscholar.org/product/api)、[API License Agreement](https://www.semanticscholar.org/product/api/license)

如果第一阶段甚至不能加静态定时聚合层，则建议先做：

```text
arXiv 候选池 + 本地按年龄 / 分类 / 关键词的可解释排序
```

并把频道名称写成“精选 / 编辑推荐”而不是“热门”，直到有可靠外部热度信号。

---

## 5. 新鲜度、成本和许可风险矩阵

| 数据源 | 主要信号 | 建议刷新 | 直接客户端成本 / 限制 | 许可与运营风险 | PaperFlow 角色 |
| --- | --- | --- | --- | --- | --- |
| arXiv API / OAI | 首发时间、版本、分类、摘要、作者 | 最新频道每日；缓存同一查询；OAI 增量同步 | 公开接口；legacy API/OAI/RSS 每 3 秒最多 1 次、单连接 | 元数据可复用；PDF / 源文件不可默认镜像；需致谢和品牌边界 | 主数据源、最新频道 |
| OpenAlex REST | 总引用、年度引用、FWCI、引用百分位 | 热榜 6～24 小时；以 API 为新鲜路径 | 免费 API Key 有每日预算；公开 Key 会暴露；免费快照更新口径需以当前官方页面 / 账号为准 | CC0，风险相对低；仍需保留来源和抓取时间 | 热榜主信号 |
| Semantic Scholar | 总引用、影响引用、图谱、推荐 | 12～24 小时或按需；不做分钟级承诺 | 未认证共享公共限额；Key 入门约 1 RPS；Key 必须保密 | API 许可限制、Key 不得公开；具体商业 / 批量使用需审阅条款 | 影响力增强、未来推荐 |
| Hugging Face | Upvote、GitHub stars、Trending、社区策展 | 6～24 小时；AI 频道可更频繁 | Hub API / 网页受全局限流；Daily Papers API/字段需监控 | 社区内容和外部链接的权利不统一；只存最小信号和来源链接 | AI 社区热度增强 |
| Papers with Code | Code、benchmark、SOTA、论文-代码关系 | 每日或更低频 | 官方客户端覆盖读写；写入需 token；不能假设稳定 SLA | CC-BY-SA；网站条款标注个人非商业用途；商业产品需法律审查 | AI 代码 / benchmark 标签 |

> **数据新鲜度定义建议：** `sourceUpdatedAt` 表示源数据本身的更新时间（只有源提供时才填）；`fetchedAt` 表示 PaperFlow 聚合任务或客户端实际抓取时间；`generatedAt` 表示榜单文件生成时间。三者不能混成一个 `updatedAt`。

---

## 6. 建议的分阶段实施顺序

### 阶段 0：不改产品语义，只准备契约

- 保持 arXiv 作为论文主源和最新频道。
- 为论文缓存预留外部 ID 和热度信号的独立结构。
- UI 暂不显示“引用数”占位数据；缺失就是缺失。
- 记录 `source`、`fetchedAt`、`matchConfidence`。

### 阶段 1：静态聚合版热门频道

- 每 6～12 小时生成热门候选 JSON。
- 第一版只接 arXiv + OpenAlex。
- 先做 `risingScore`，再补 `evergreenHotScore`。
- Semantic Scholar 作为可配置增强，HF 作为 AI 可选增强，PWC 默认关闭。
- Flutter 只读静态榜单；失败时回退上一个版本和本地缓存。

### 阶段 2：数据质量与可解释性

- 增加 DOI / arXiv ID / 标题匹配审计。
- 增加去重、撤稿 / retraction 过滤和异常值标记。
- 对每个分类设置候选配额。
- 显示热度来源与更新时间。
- 用离线快照做排序回放，检查新论文和老论文是否长期失衡。

### 阶段 3：未来个性化推荐

- 以阶段 1 的热门候选作为召回池，不直接从全量 arXiv 做用户级排序。
- 根据用户关注分类、作者、已读 / 收藏 / 稍后阅读做客户端重排。
- 仍保留“热门基础分”作为冷启动和探索项。
- 用户规模和隐私需求明确后，再把用户画像与重排迁移到自有后端。

---

## 7. 最终决策

### 推荐采用

```text
候选主源：arXiv
学术热度：OpenAlex
影响力增强：Semantic Scholar（聚合层可选）
AI 社区增强：Hugging Face（可选）
代码 / benchmark 标签：Papers with Code（默认非核心）
发布形态：静态定时聚合 JSON，而不是 Flutter 多源直连
```

### 不推荐采用

- 只按 arXiv `relevance` 作为热门。
- 只按 OpenAlex `cited_by_count` 全局降序。
- 把 Semantic Scholar API Key 写入 Flutter 客户端。
- 把 HF GitHub stars、upvote 或 PWC benchmark 数量直接叫“引用量”。
- 把 Papers with Code CC-BY-SA 数据整库复制进产品而不处理署名、ShareAlike 和商业条款。
- 把所有外部源的失败降级成虚假的 `0`，造成用户误以为论文没有影响力。

### 一句话结论

**PaperFlow 的“推荐”首版应是“arXiv 候选池 + OpenAlex 学术影响 + 可选的 Semantic Scholar / HF / PWC 增强 + 静态聚合榜单”；arXiv 负责“最新”，不负责“热门”，个性化只在这套基础候选之上以后再做。**


