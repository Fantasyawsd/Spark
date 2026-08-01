# PaperFlow 架构审查记录

> 日期：2026-08-01
> 状态：持续整改
> 依据：[`../standards/code-structure.md`](../standards/code-structure.md)

## 本轮结论

当前项目已按业务模块组织，并建立 Repository、Service 和 Controller 边界，但仍存在应用组合根分散、聊天反向依赖论文实现、领域类型混合展示字段等结构风险。本轮优先整改会直接阻碍本地功能继续开发的评论模块。

## 已整改

- 新增 `PaperCommentController`，评论加载、发送、回复、点赞、删除、排序和串行持久化不再由 Bottom Sheet Widget 实现。
- 论文操作栏与评论 Sheet 共享同一评论状态源，发送和删除后计数即时更新。
- 评论 Repository 通过领域接口注入，正式入口使用文件实现，测试使用内存实现。
- 相关论文从 Markdown 字符串改为结构化 `RelatedPaper`，页面只通过论文 ID 请求 `PaperFeedController` 打开目标。
- Profile 收藏列表消费真实收藏状态，不在资料页复制收藏业务逻辑。
- 新增评论控制器和文件型评论 Repository 测试，覆盖计数、排序、级联删除、重建恢复与损坏数据。
- 新增聊天领域消息、会话摘要和 `ChatSessionRepository` 端口，稳定会话契约不再由论文模块拥有。
- 新增 `ChatSessionController`，统一负责会话加载、主聊天识别、论文上下文过滤、排序、置顶、删除和错误状态。
- `MessagesScreen` 不再导入 `PaperRecord` 或直接调用 Repository，只消费聊天会话 ViewModel 与命令。
- App Shell 作为组合根将论文 ID 和标题映射为 `ChatContextSummary`，并在任意聊天入口返回后刷新全局会话列表。
- 新增聊天会话控制器测试，覆盖排序、过滤、上下文更新、置顶、删除、错误与异步销毁安全。
- 新增独立 `PaperReadingRepository` 与 `PaperReadingController`，阅读历史、已读、稍后阅读、内部 Tab、摘要滚动位置和停留时长不再散落于 Widget 状态。
- Profile 的阅读历史从固定 Demo 统计改为真实论文列表，并增加真实稍后阅读列表；页面只消费领域对象和打开论文回调。
- 扩展论文偏好快照，按筛选条件保存论文位置及最后选中的一级/二级分类，应用重建后可恢复。
- 修复 `PaperFeedController` 异步偏好写入在销毁后通知监听器的生命周期错误。
- `CommunityPost` 与 `MessageItem` 已移除 Flutter 依赖，领域实体恢复为纯 Dart 类型。
- Community 和 Messages 的演示数据已迁至各自的 `data` 层，不再与领域实体定义混放。
- 仅由 Community 使用的 `PaperDiagram` 已从 `core/widgets` 迁回该业务模块的展示层。
- 论文互动与评论写入已增加版本化快照回滚：最新写入失败恢复最后一次成功状态，旧失败不会覆盖后续操作。
- 评论控制器已拥有发送状态、防重复提交和失败重试语义，Sheet 仅负责恢复输入与展示进度。
- 互动初始化期间的用户操作会在持久化快照加载后按顺序重放，未加载的空状态不再覆盖已有互动数据。
- 评论与 AI 使用独立输入控制器，异步评论失败不会把文本恢复到 AI 输入框。
- 互动错误使用单调版本号展示，论文页在后台发生失败后会在重新激活时补发提示。
- AI 会话已增加显式请求状态和可持久化的取消标记，主动停止后可跨重启保留已有流式内容并重新生成；请求错误与持久化错误分别管理，清空操作与会话保存使用同一版本化写队列。
- 互动、偏好、阅读、评论、翻译、AI 会话和搜索历史仓储已统一使用带独立业务 schema 的本地 JSON 信封；旧裸格式读取后自动迁移，格式和业务 schema 都支持逐版本迁移链，允许各仓储独立演进，未知格式或未来版本不会被旧客户端覆盖。
- 本地 JSON 存储在当前 Dart isolate 内使用规范化同路径事务队列和临时文件替换；Windows 替换期间保留恢复文件，读取时可恢复中断写入前的数据。只有 JSON 或已知 schema 结构损坏才隔离原文件，普通文件系统错误不移动用户数据。
- 完整快照写入使用信封 revision 做乐观并发检查，检测到其他仓储实例已更新磁盘数据时拒绝陈旧覆盖；评论、翻译和 AI 会话继续通过事务更新最新磁盘值。
- 各文件仓储的 JSON Record 解析已集中到所属业务模块的 Mapper，字段存在但类型错误时会保留损坏副本，不再静默恢复为空状态后覆盖原始数据。
- 新增 `PaperFlowDependencies` 作为唯一应用组合根：正式入口集中创建文件仓储、平台服务和 DeepSeek 实现，`PaperFlowShell` 只消费依赖接口；旧的可选构造参数仅保留给测试和预览兼容层。
- 增加组合根装配测试，覆盖正式实现类型、预览替身注入以及论文 AI 与主聊天 AI 的默认/独立服务映射。
- 新增通用 `ChatContext`、`ChatAiService` 与 `ChatConversationController`，主聊天不再通过伪造 `PaperRecord` 复用论文会话；论文模块只通过 `PaperChatContext` 适配论文提示词和稳定会话 ID。
- AI Composer、会话内容和消息视图已迁入 `chat/presentation`；论文模块旧路径只保留导出兼容层。Markdown 渲染与入场动画因被论文和聊天共同使用，迁入 `core/widgets`。
- DeepSeek 实现和文件/内存会话仓储已直接依赖 `chat` 的端口与领域类型，不再通过 `papers/application` 兼容别名反向依赖；论文 AI 类型别名仅保留给现有论文调用方渐进迁移。
- 论文领域实体已由 `PaperRecord` 更名为 `Paper`；作者改为结构化列表，正文与统计值拆为领域值对象，引用、点赞、评论、收藏和分享计数恢复为整数，紧凑数字只由展示层格式化。
- 0.1.0 主导航已收敛为“论文 / ChatPaper / 我的”；ChatPaper 会话首页和左滑操作从 `messages` 迁入 `chat`，不再混合私信、通知 Demo，社区与消息模块不参与正式组合根或公共导出。
- 收藏状态已从单一 ID 集合升级为领域化分组模型：默认分组保持稳定 ID，自定义分组及论文成员关系随互动快照持久化；旧 `savedPaperIds` 通过 schema v2 迁移到默认分组。论文页只发出收藏命令，“我的”只消费分组视图和窄回调。
- 论文阅读入口已按职责拆分：`PapersScreen` 只编排可上下刷新的 Feed、分类顶栏和 Dock，`PaperDetailScreen` 只编排外部入口的全屏阅读与路由返回；两者通过模块内 `PaperReaderView` 统一连接 `PaperReaderCard`、Controller 和平台服务，搜索、收藏、历史和相关论文不再通过修改 Feed 索引模拟跳转。
- App Shell 统一拥有论文详情路由栈和覆盖状态。嵌套打开相关论文会继续压栈，返回逐级恢复上一个详情或原入口；被覆盖的首页 Feed 暂停阅读停留计时，详情页通过共享路由可见性观察器只累计前台可见时间。
- 新增 `PaperCatalogRepository` 异步分页端口；arXiv Atom Provider DTO、论文缓存 Record 和领域 `Paper` 通过 Mapper 分层转换，远程 JSON/XML 不进入 Controller 或 Widget。
- 新增 `OfflineFirstPaperCatalogRepository`，按远程、查询缓存、内置种子顺序提供 Feed/Search/详情；生产组合根注入该目录仓储，预览与测试默认仍使用同步种子避免隐式网络请求。
- `PaperFeedController` 保留冷启动同步种子视图，并在目录仓储可用时异步刷新和接近末尾加载更多；`PaperSearchController` 保留本地即时搜索兼容路径，并在生产入口使用远程搜索结果更新。
- 新增独立 `ai_settings` 业务模块：领域层定义 DeepSeek 凭据与验证端口，数据层分别实现安全存储和远程验证，应用层控制配置状态；Profile 只消费控制器，不读取 Key 或平台插件。
- DeepSeek 聊天、联网搜索和翻译服务在每次请求前通过凭据端口读取当前 Key，同时保留显式构造参数供协议测试和私人开发构建使用。
- Android 最低版本调整为 API 23，并关闭应用备份，避免 Keystore 密文被恢复到不匹配设备。
- Profile 已从虚构个人主页收敛为本地研究工作台：删除网络头像、身份、VIP、社交、通知、帖子、草稿和下载 Demo，只消费真实收藏、阅读、AI 凭据和应用设置状态。

## 高优先级待整改

1. **本地数据管理**：Profile 已展示真实数据摘要，但还需要跨仓储的清理用例；必须由应用层协调论文缓存、聊天和本地业务仓储，Widget 不直接删除文件。

## 中优先级待整改

- `PaperController` 当前是 `PaperFeedController` 与 `PaperInteractionController` 的兼容外观。保留用于过渡，待调用方全部改为窄接口后再删除，不立即重构。
- `paperflow_markdown.dart` 同时承担渲染、代码块解析、LaTeX 预处理、流式修复和剪贴板操作。当前作为论文与聊天共享能力保留在 `core/widgets`；后续新增解析能力时再按职责拆分。
- 仅由单个业务模块使用的组件不应继续放入 `core/widgets`；迁移时以真实复用关系为准，不进行批量目录改名。

## 继续开发约束

- 新功能先定义领域对象和端口，再实现 Controller，用 Widget 测试验证界面接线。
- Widget 不直接读写文件、HTTP、系统插件或 Repository。
- 正式依赖在组合根创建；测试通过构造参数注入内存实现。
- 不为一次或两次重复提前抽象；稳定出现三次后再建立 shared 能力。
- 每次结构调整必须保持现有交互，并至少执行 `flutter analyze`、相关测试和全量测试。
