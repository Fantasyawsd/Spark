# PaperFlow 架构审查记录

> 日期：2026-08-01
> 状态：持续整改
> 依据：`code-structure-principles.md`

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

## 高优先级待整改

1. **聊天模块所有权**：通用消息和会话端口已迁入 `chat`，但 ConversationController、Composer 和内容渲染仍复用 `papers` 类型。后续应由聊天模块拥有通用对话流程，论文模块只提供论文聊天上下文。
2. **唯一组合根**：`PaperFlowShell.initState` 仍创建若干 DeepSeek、搜索和平台实现。具体实现应统一在 `main.dart` 或 `AppDependencies` 创建；`PaperFlowApp` 的内存 fallback 只用于测试和预览。
3. **依赖方向**：部分 `papers/data` 实现仍通过兼容别名导入 `papers/application` 端口。后续应直接依赖 `chat/domain`，使依赖统一为 `presentation -> application -> domain <- data`。
4. **数据结构分层**：`PaperRecord` 仍混合原始论文值、Markdown 展示内容和格式化计数字符串。远程接口接入前应拆分 DTO、领域模型和 ViewModel，并把计数恢复为整数。

## 中优先级待整改

- `PaperController` 当前是 `PaperFeedController` 与 `PaperInteractionController` 的兼容外观。保留用于过渡，待调用方全部改为窄接口后再删除，不立即重构。
- `paper_markdown.dart` 同时承担渲染、代码块解析、LaTeX 预处理、流式修复和剪贴板操作。后续出现第三个调用方或新增解析能力时再按职责拆分。
- 仅由单个业务模块使用的组件不应继续放入 `core/widgets`；迁移时以真实复用关系为准，不进行批量目录改名。

## 继续开发约束

- 新功能先定义领域对象和端口，再实现 Controller，用 Widget 测试验证界面接线。
- Widget 不直接读写文件、HTTP、系统插件或 Repository。
- 正式依赖在组合根创建；测试通过构造参数注入内存实现。
- 不为一次或两次重复提前抽象；稳定出现三次后再建立 shared 能力。
- 每次结构调整必须保持现有交互，并至少执行 `flutter analyze`、相关测试和全量测试。
