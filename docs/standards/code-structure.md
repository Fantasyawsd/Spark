# PaperFlow 代码结构原则

> 状态：强制执行  
> 适用范围：PaperFlow 全部生产代码、测试代码和后续重构  
> 最近更新：2026-08-03

## 1. 目的

本文规定 PaperFlow 的代码组织、模块边界和依赖方向。后续功能开发与代码审查必须遵循这些规则，以继续开发和长期可维护性为主要目标。

这些规则是项目约束，不是可选建议。确需例外时，应在代码审查中说明原因、影响范围和后续处理方式。

## 2. 核心原则

### 2.1 单一职责

一个文件、类和函数只承担一种主要职责。

- 页面 Widget 负责页面组合，不负责数据获取、持久化或复杂业务判断。
- Controller 负责用例状态和业务协调，不负责具体数据库、文件或 HTTP 实现。
- Repository 负责领域数据访问抽象，不负责 UI 状态。
- Data Source 负责一种具体基础设施访问方式。
- Mapper 只负责数据类型转换。
- 一个函数只处于一个抽象层级，不在同一函数中混合 UI、业务决策、序列化和网络请求。

当一个类需要用“并且”描述多个独立职责时，应考虑拆分。

### 2.2 分层架构

业务模块内部采用明确分层：

```text
presentation
    -> application
        -> domain

data / infrastructure
    -> domain
```

依赖方向只能指向领域内层：

- `presentation` 可以依赖 `application` 和 `domain`。
- `application` 可以依赖 `domain`。
- `data` 可以依赖 `domain` 中的接口和实体。
- `domain` 不依赖 Flutter、数据库、HTTP、平台插件或具体 data 实现。
- `application` 不直接依赖具体数据库客户端和 HTTP 客户端。

禁止 `domain` 反向导入 `presentation`、`data` 或 `infrastructure`。

### 2.3 按业务划分模块

模块优先按业务能力划分，不按纯技术类型集中堆放。

推荐结构：

```text
lib/src/features/
|-- papers/
|   |-- domain/
|   |-- application/
|   |-- data/
|   `-- presentation/
|-- comments/
|-- search/
|-- profile/
`-- community/
```

判断归属时先问“这段代码属于哪个业务能力”，而不是“它是 Widget、工具类还是 Service”。

功能只被一个业务模块使用时，应留在该模块中。只有真正跨模块复用且不包含具体业务语义的代码，才可以进入 `core` 或 `shared`。

### 2.4 高内聚、低耦合

一个模块内部的代码应围绕同一业务能力高度相关，不同模块只通过少量、明确的公开接口交互。

- 不允许其他模块直接访问模块内部的私有状态或具体 Data Source。
- 不跨模块读取另一个 Controller 的内部集合。
- 模块对外暴露领域对象、用例接口或窄回调，不暴露实现细节。
- 避免依赖包含大量无关方法的“大接口”。
- 一个模块的内部重构不应迫使无关模块修改。

### 2.5 依赖倒置

业务层依赖抽象接口，不直接依赖具体实现。

示例：

```dart
abstract interface class CommentRepository {
  Future<List<Comment>> getByPaper(String paperId);
  Future<Comment> addComment(AddCommentCommand command);
}
```

应用层只依赖 `CommentRepository`。本地 JSON、SQLite、内存测试实现和未来远程 API 分别实现该接口。

禁止在 Controller、Use Case 或页面 Widget 中直接创建：

- 数据库客户端
- 文件读写对象
- `http.Client`
- 具体远程 Repository
- 具体本地存储实现

具体实现应在应用组合根中注入。

### 2.6 区分业务逻辑和基础设施逻辑

业务逻辑包括：

- 分类规则
- 搜索匹配规则
- 点赞、收藏和评论状态变化
- 评论回复关系
- 推荐与关注规则
- AI 对话上下文组织规则

基础设施逻辑包括：

- HTTP 请求
- JSON 编解码
- SQLite、文件或键值存储
- 系统分享
- 剪贴板
- DeepSeek SDK 或 API 调用

业务逻辑放在 `domain` 或 `application`；基础设施逻辑放在 `data`、`infrastructure` 或对应平台适配器中。两者不能混在页面 Widget 或同一个函数中。

### 2.7 数据结构分层

不要让同一个类型贯穿数据库、业务层、API 和前端。

建议区分：

```text
API DTO
  -> Mapper
Domain Entity
  -> Presenter / View Model
UI

Database Record
  -> Mapper
Domain Entity
```

- API DTO 反映接口字段和可空规则。
- Database Record 反映本地存储结构。
- Domain Entity 表达业务不变量和领域语义。
- View Model 只包含当前 UI 所需的展示状态。
- JSON 注解、数据库注解和 Flutter Widget 类型不进入领域实体。

字段格式化应尽量靠近展示层。例如数量在领域层使用 `int`，`1.2k` 只在展示层生成。

### 2.8 控制文件、类和函数粒度

- 页面文件负责布局编排，复杂区块拆成业务模块内组件。
- Controller 不承担多个互不相关的业务流程。
- 函数只处理一个抽象层级。
- 当函数需要大量注释分段说明多个步骤时，应考虑提取用例或私有函数。
- 当文件同时包含页面、领域模型、数据访问和业务状态时，必须拆分。

行数不是唯一标准，但出现以下信号时必须审查拆分：

- 文件难以一次理解主要职责。
- 修改一个功能经常触碰同一大文件中的无关区域。
- 测试只能通过构建完整页面来验证小段业务逻辑。
- 多个 State 类共同维护同一业务状态。

### 2.9 公共代码边界

优先把代码放在所属业务模块中。

只有同时满足以下条件，代码才可以进入 `core` 或 `shared`：

1. 至少两个独立业务模块真实使用。
2. 不包含某个业务模块的领域语义。
3. API 已经稳定。
4. 公共模块不需要反向依赖具体业务模块。

`utils` 中不得包含业务逻辑。避免使用含义宽泛的 `helpers.dart`、`utils.dart`、`common.dart` 作为代码堆放位置。

### 2.10 避免循环依赖

- 业务模块之间不能互相导入实现层。
- 公共模块不能依赖具体业务模块。
- 跨模块协作通过领域接口、应用服务或事件结果完成。
- 出现循环依赖时，应重新识别共同抽象或调整模块所有权，不用新增全局工具类绕过问题。

### 2.11 组合优于继承

- Widget 行为优先通过组合、参数和小组件构建。
- 业务能力优先通过注入接口和组合 Use Case 构建。
- 不建立深层基类体系共享少量代码。
- 只有存在稳定的“是一个”关系且多态确有价值时才使用继承。

### 2.12 避免过度抽象

遵循“三次原则”：

1. 第一次出现：直接实现，保持简单。
2. 第二次出现：观察两处是否真的具有相同语义和变化方向。
3. 第三次稳定重复：再考虑提取抽象。

相似代码不一定属于同一抽象。只有业务语义、生命周期和变化原因都一致时才复用。

不要为了未来可能出现的需求预先创建空接口、通用基类、全局事件总线或复杂泛型框架。

### 2.13 顶层目录与边界

`lib/src/` 的顶层是闭合集合，只有三个目录，每个有唯一 charter：

| 目录 | Charter（职责） | 边界（不属于它的） |
| --- | --- | --- |
| `app/` | 应用组合根：入口装配、依赖注入、导航壳与全局组装 | 业务逻辑；可复用组件 |
| `core/` | 真正跨业务复用的基础设施：配置、主题、动画、导航、存储、通用组件 | 任何业务语义；被业务模块反向依赖 |
| `features/` | 业务模块集合：一个业务能力一个目录，内部按 `presentation → application → domain`（及 `data`）分层 | 跨模块内部互导；纯技术类型堆放 |

charter 的判断测试：把 `core/` 搬到另一个应用，再配上新业务代码，就构成另一个应用——`core/` 不应携带任何 PaperFlow 业务语义。

### 2.14 闭合顶层规则

新能力一律按性质路由进现有顶层目录，禁止在 `lib/src/` 新建顶层目录：

| 能力性质 | 归属 |
| --- | --- |
| 业务能力（论文、聊天、设置、搜索……） | `features/<模块>/` |
| 跨业务复用的基础设施（主题、动画、存储、导航、通用组件） | `core/` 对应子目录 |
| 组合根装配、依赖注入、导航壳 | `app/` |

判断依据是「这段代码属于哪个业务能力或哪类基础设施」，而不是文件类型或体积。能力不属于任何现有 `core/` 子目录，不是新建 `lib/src/` 顶层目录的理由——先在 `core/` 内找到归属，或调整模块边界使归属成立。

### 2.15 模块公共入口

模块之间只通过少量明确入口交互，不暴露实现细节：

- 跨模块协作通过领域接口、应用服务或 `core/` 的公开组件完成。
- 禁止深导入其他模块内部实现（如 `features/papers/data/...`、`features/chat/application/...` 的具体文件）。
- `core/` 子目录的公开文件（如 `PaperFlowColors`、`PaperFlowTheme`、通用组件）就是它的公共入口，业务模块不访问其私有实现文件。

### 2.16 放置反模式

以下放置决策是反模式，出现时应修正：

- 业务逻辑放入 `app/` 或 `core/`。
- 一个业务模块导入兄弟业务模块的内部实现（跨模块耦合）。
- 为单个能力新建 `lib/src/` 顶层目录。
- 用宽泛的 `utils.dart`、`common.dart` 之类文件堆放不属于任何模块的代码。
- 把基础设施实现放入领域层文件（`domain` 依赖 Flutter、HTTP 或数据库）。

§6 的审查阻断条件负责行为级门禁，本节的放置反模式负责结构级归属，两者互补不重复。

## 3. PaperFlow 目标依赖结构

以论文功能为例：

```text
papers/presentation
  PaperScreen
  PaperFeedView
  PaperGridView
  PaperActionBar
       |
       v
papers/application
  PaperFeedController
  PaperInteractionController
  Use Cases
       |
       v
papers/domain
  Paper
  PaperInteraction
  PaperRepository
  InteractionRepository
       ^
       |
papers/data
  DemoPaperRepository
  LocalPaperRepository
  RemotePaperRepository
  DTO / Record / Mapper
```

评论和搜索如果形成独立业务能力，应拥有自己的模块和 Repository，不继续堆入 `papers_screen.dart` 或 `paper_comments_sheet.dart`。

## 4. 本地优先与未来数据库迁移

第一阶段先实现本地功能，但本地实现也必须遵守分层和依赖倒置：

```text
UI -> Controller -> Repository interface <- Local implementation
```

未来接数据库或后端时替换右侧实现：

```text
UI -> Controller -> Repository interface <- Remote implementation
```

不得以“目前只是本地功能”为理由，让 Widget 直接读写文件、键值存储或 JSON。否则数据库迁移会迫使 UI 和业务逻辑一起重写。

## 5. 提交前结构检查清单

每次新增功能或重构前检查：

- [ ] 文件、类和函数是否各自只有一个主要职责？
- [ ] 新代码是否放在正确的业务模块？
- [ ] 业务规则是否离开了 Widget 和基础设施实现？
- [ ] 应用层是否依赖抽象接口而非具体实现？
- [ ] API DTO、数据库 Record、领域实体和 View Model 是否分开？
- [ ] 公共代码是否确实被多个业务模块稳定复用？
- [ ] `core`、`shared`、`utils` 是否没有业务逻辑？
- [ ] 是否引入了反向依赖或循环依赖？
- [ ] 是否可以用组合代替继承？
- [ ] 抽象是否满足稳定重复，而不是为假设需求提前设计？
- [ ] 小范围业务逻辑是否可以脱离完整页面进行单元测试？
- [ ] 本地实现未来是否可以在不修改 UI 的情况下替换为远程实现？
- [ ] 开始开发前是否确认了分支、工作区和未提交改动的归属？
- [ ] 本次暂存是否使用明确路径，而不是 `git add .`？
- [ ] 暂存区是否只包含一个主要职责和一组可独立验证的改动？
- [ ] 是否已经检查 `git diff --cached`、`git diff --check` 和敏感信息？
- [ ] 阶段性交付后工作区是否能够恢复到清晰、可解释的状态？

## 6. 代码审查阻断条件

出现以下情况时，不应继续合并新功能，应先修正结构：

- Widget 直接访问数据库、文件或 HTTP。
- Controller 直接创建具体 Repository 或平台插件。
- 领域层依赖 Flutter、HTTP 或数据库包。
- 一个数据类型同时承担 API DTO、数据库记录、领域实体和 UI 模型。
- 公共模块反向依赖具体业务模块。
- 新增循环依赖。
- 将业务规则放入通用 `utils`。
- 为复用少量代码建立深层继承体系。
- 在已有超大页面文件中继续加入独立业务流程。
- 新功能无法通过独立单元测试验证，只能依赖完整 UI 测试。

## 7. Git 版本管理

Git 的预检、分支、worktree、原子提交、暂存、回滚和交付规则统一定义在：

[`version-control.md`](version-control.md)

本文件只保留与代码结构相关的提交前检查项。版本管理文档是强制门禁；如果当前工作区无法明确区分任务归属，必须停止新增功能，不得以一次“大 checkpoint”替代真实的版本边界。
