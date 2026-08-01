# PaperFlow 0.2.0 论文频道、索引与阅读改进计划

> 状态：需求已确认，尚未开发。
> 最近更新：2026-08-02
> 参考产品：[Cool Papers](https://papers.cool/)

## 1. 目标与边界

本版本借鉴 Cool Papers 的可组合论文索引和内容发现方式，但不复制其桌面端密集列表。PaperFlow 继续以 Android 手机信息流为主，重点解决频道扩展、论文元数据语义、内容关键词和深度 AI 解读。

本版本暂不实现引用数、跨用户热度、全量 BM25 搜索、引用图谱和云端共享结果。没有真实数据源的会议频道不得以 Demo 数据进入生产入口。

## 2. 顶部论文频道

顶部频道统一使用“文字 + 选中下划线”样式：

```text
推荐  关注  最新  人工智能  计算与语言  机器学习  ICML  ACL  ＋
```

- 推荐、关注和最新固定存在，不能删除。
- 用户添加的主题和会议频道显示在固定频道之后。
- 频道栏横向滚动，`＋` 固定在右侧并始终可见。
- 每个频道独立保存论文位置、加载状态和分页状态。
- 用户频道支持添加、删除、排序和本地持久化。
- 主题和会议是独立索引，不再作为推荐页中的临时筛选条件。

## 3. 添加频道

点击 `＋` 打开频道管理页，页面分为“按主题”和“按会议”两部分，并支持搜索与已添加状态。

### 3.1 arXiv 主题频道

首批主题使用中文显示，领域层保留真实 arXiv 分类编号：

| 显示名称 | arXiv 分类 |
| --- | --- |
| 人工智能 | `cs.AI` |
| 计算与语言 | `cs.CL` |
| 计算机视觉与模式识别 | `cs.CV` |
| 机器学习 | `cs.LG` |

后续主题必须来自结构化 arXiv 分类目录，不能只保存用户可见字符串。内容关键词与 arXiv Subjects 是两种不同数据，禁止互相代替。

### 3.2 会议频道

首批会议目录：

```text
AAAI  ACL  COLM  COLT  CoRL  CVPR  ECCV  EMNLP  ICCV
ICLR  ICML  IJCAI  INTERSPEECH  IWSLT  MICCAI  MLSYS
NAACL  NDSS  NeurIPS  OSDI  UAI  USENIX-Fast  USENIX-Sec
```

会议索引结构为“会议 -> 年份 -> Track/论文类型”，例如：

```text
ACL 2026 · Long Paper
ICML 2026 · Oral
CVPR 2026 · Highlight
NeurIPS 2025 · Poster
```

会议频道需要独立的 `VenueCatalogSource` 适配器和稳定来源 ID。OpenReview、ACL Anthology、PMLR、IJCAI 等远程类型必须先转换为领域模型，Widget 不直接处理提供方字段。

## 4. 时间筛选

原领域筛选按钮改为时间筛选，对当前频道生效：

```text
不限时间
最新发布日
最近 7 天
最近 30 天
选择日期
自定义时间范围
```

arXiv 频道使用发布时间范围；会议频道优先使用会议年份，来源提供具体发布日期时再支持日期范围。切换时间条件后必须改变真实查询和缓存键，不能只改变界面文案。

## 5. 论文索引信息

### 5.1 arXiv 论文

至少保存并展示：

- arXiv ID、标题、作者；
- Abstract；
- Primary Subject 和全部 Subjects；
- Publish Time 和 Update Time；
- 原始论文地址和 PDF 地址；
- DOI、Journal Reference、Comment 和 License，有值时才显示。

### 5.2 会议论文

至少保存并展示：

- 稳定来源 ID、标题、作者和 Abstract；
- 会议名称、年份、Track 或论文类型；
- 原始来源和 PDF 地址；
- 来源提供的发布时间、DOI 和其他元数据。

### 5.3 数据语义

- `source`、`venue`、`journalReference` 和 `affiliation` 分开存储。
- 单位未知时保持为空，不能使用 `arXiv` 代替单位。
- 引用数暂缓实现，未知引用数不能显示为“被引 0”。
- arXiv Subjects 负责分类索引，内容关键词负责论文语义发现。

## 6. 论文内容页面

论文阅读区改为六个内容宽度的横向滚动 Tab：

```text
Abstract  摘要  关键词  作者与单位  AI 解读  相关论文
```

每次进入或切换论文默认打开 `Abstract`，不能继承上一篇论文的 Tab。六个页面共用稳定高度边界，切换时不能造成卡片、操作栏或 Dock 跳动。

### 6.1 Abstract

- 展示英文原始摘要，支持 Markdown、公式、选择和滚动。
- 使用左对齐和紧凑行距。
- 只有内容实际溢出时才显示展开入口。

### 6.2 摘要

- 展示中文摘要翻译，继续按论文和内容版本缓存。
- 用户只看到“生成中文摘要、正在生成、失败重试”等产品状态。
- 不显示模型名称、思考模式开关状态或“DeepSeek 中文翻译”等内部实现文案。

### 6.3 关键词

- 从论文标题和 Abstract 提取 5 至 12 个内容关键词。
- PDF AI 解读完成后，可以使用全文结果更新关键词。
- 关键词按重要程度排序并写入本地缓存。
- `cs.AI`、`cs.LG` 等 Subjects 不能作为内容关键词冒充展示。

### 6.4 作者与单位

- 展示完整作者列表以及能够可靠匹配的单位。
- 第一作者、通讯作者等角色只有来源明确时才标记。
- 单位缺失时不猜测、不填充占位来源名称。
- 后续可以接入 OpenAlex 或 PDF 解析增强作者单位关系。

### 6.5 AI 解读

用户点击后才生成以下固定结构：

1. **Q1：这篇论文试图解决什么问题？**
2. **Q2：有哪些相关研究？**
3. **Q3：论文如何解决这个问题？**
4. **Q4：论文做了哪些实验？**
5. **Q5：有什么可以进一步探索的点？**
6. **Q6：总结一下论文的主要内容。**

生成流程：

```text
下载 PDF -> 提取正文 -> 清理噪声 -> 分块分析 -> 汇总六问 -> 本地缓存
```

模型不原生支持 PDF 文件时，基础设施层先提取文本，再按章节或 Token 上限分块发送。缓存键至少包含论文 ID、PDF 版本或哈希、提示词版本、模型版本和输出语言。

生成结果作为该论文 ChatPaper 会话的默认上下文，但不作为普通消息重复显示。聊天上下文包含论文元数据、Abstract、关键词和六问答案。

### 6.6 相关论文

本版本先保留页面边界和状态模型，真实语义检索延期实现。后续综合使用标题、内容关键词、Abstract 向量、Subjects、作者关系和引用关系；第一阶段可以从“标题 + 关键词”语义检索开始。

## 7. 本地缓存与云端演进

0.2.0 单机阶段按需生成并在设备本地保存：

- 中文摘要；
- 内容关键词；
- PDF 提取结果；
- 六问 AI 解读；
- 论文 ChatPaper 会话。

后续云端服务以稳定论文 ID 和内容版本为键共享中文摘要、关键词、AI 解读、PDF 解析结果和语义向量。同一版本论文只生成一次，客户端 Repository 接口不因本地缓存替换为云端实现而改变。

## 8. 推荐领域接口

```dart
class PaperChannel {
  final String id;
  final String label;
  final PaperChannelKind kind;
  final PaperIndexQuery query;
}

class PaperIndexQuery {
  final Set<String> categoryIds;
  final String? venueId;
  final DateTimeRange? publishedRange;
  final PaperIndexSort sort;
}
```

上述类型属于 `features/papers` 业务模块。arXiv、OpenReview、ACL 和 PMLR 查询参数由数据层 Mapper 转换，不能进入 Controller 或 Widget。

## 9. 开发顺序

1. 修正 `Paper` 的 source、venue、subject、publish time 和 affiliation 语义。
2. 建立结构化频道、分类目录、时间条件和版本化偏好迁移。
3. 重做顶部频道栏和 `＋` 频道管理页。
4. 将旧领域筛选入口改为时间筛选。
5. 接入真实 arXiv 主题查询并验证缓存键、分页和位置恢复。
6. 建立会议数据源端口，至少完成一个真实会议提供方的纵向闭环后再开放会议频道。
7. 将论文内容改为六页结构并保持布局稳定。
8. 完成内容关键词、作者与单位以及中文摘要缓存。
9. 实现 PDF 下载、文本提取、六问 AI 解读和 ChatPaper 上下文。
10. 最后实现相关论文语义检索和云端共享缓存。

## 10. 验收标准

- 添加或移除频道后，频道栏和本地配置同步更新。
- 每个频道查询、分页、错误状态和浏览位置互不污染。
- 时间筛选改变真实请求，离线时只使用匹配条件的缓存。
- arXiv 论文显示 Subjects 和 Publish Time；会议论文显示会议、年份和 Track。
- 未知单位和未知引用数不会显示成虚假数据。
- 内容关键词不包含仅用于分类的 arXiv 编号。
- 每篇论文默认进入 Abstract，六页切换无闪烁和高度跳变。
- AI 解读只在用户触发后下载和处理 PDF，失败可重试且不会破坏旧缓存。
- AI 解读完成后，新建论文聊天能读取六问结果作为默认上下文。
- `flutter analyze`、相关 Widget/单元测试、全量 `flutter test` 和 Android debug APK 构建通过。
