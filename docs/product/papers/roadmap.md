# PaperFlow 论文开发路线

> 状态：持续维护
> 最近更新：2026-08-03
> 文档入口：[`../../README.md`](../../README.md)
> 当前发布：[`../../releases/0.1.0/README.md`](../../releases/0.1.0/README.md)
> 具体计划：[`channels-and-reading.md`](channels-and-reading.md)（频道、索引、六页阅读、PDF 六问 AI 解读）

## 文档定位

- 本文维护论文领域的能力现状、边界、优先级和技术路线。
- 频道与阅读信息架构的具体计划维护在 [`channels-and-reading.md`](channels-and-reading.md)，不按计划版本复制。
- 代码结构和 Git 管理分别遵守 [`../../standards/code-structure.md`](../../standards/code-structure.md) 与 [`../../standards/version-control.md`](../../standards/version-control.md)。

## 当前能力

- 论文、ChatPaper、我的三个一级页面，本地功能形成完整单机闭环。
- 正式组合根接入 arXiv Atom 远程目录、版本化论文缓存与离线回退，内置种子保证冷启动。
- 本地搜索、点赞、收藏、评论、分享、阅读历史、稍后阅读和自定义收藏分组已持久化。
- DeepSeek BYOK 流式翻译与对话；密钥存设备安全存储，公开构建不含共享 Key。
- 主要 UI 流程有 Widget 测试覆盖，Android debug APK 可重复构建。

## 当前边界

- 无账号、无跨设备同步、无服务端代理；关注、收藏、评论等均为本地状态。
- 相关论文使用结构化本地关系，未接入真实引用图谱。
- AI 上下文只有论文元信息与摘要，不含全文、图表或参考文献。
- 远程导入与同步适配器已提供；完整快照、论文库与服务端 PaperStore 属于服务端阶段。

## 后续方向

### 频道、索引与阅读（详见 channels-and-reading.md）

- 统一推荐、关注、最新、用户主题与会议频道模型。
- 补齐 arXiv 结构化元数据、会议目录与时间筛选。
- 六页阅读结构（Abstract / 摘要 / 关键词 / 作者与单位 / AI 解读 / 相关论文）。
- PDF 下载、文本提取与六问 AI 解读，作为论文 ChatPaper 默认上下文。

### 服务端与数据闭环

- 用户登录，点赞、收藏、评论、关注与搜索历史同步，本地未同步操作队列。
- DeepSeek 后端代理：安全保存 Key、额度、限流、会话云持久化与成本控制。
- 论文级共享派生数据：中文摘要、关键词、AI 解读、PDF 解析与语义向量的云端缓存。
- arXiv 完整快照与增量同步、论文库接入。

### 深度功能与推荐

- 结构化作者与机构、关键词、BibTeX、参考文献与引用关系。
- 推荐系统利用阅读、停留、互动与关注信号，支持去重、排除已读和推荐原因。

## 验收原则

- 未知数据和未知状态不显示为虚假数据（引用数、单位、会议 Track）。
- Repository / Service 接口保持稳定，本地实现替换为服务端时 UI 不重写。
- 完成项必须有代码、测试、构建或人工验收证据。
- `flutter analyze`、`flutter test`、Android debug APK 构建通过；不启动模拟器。
