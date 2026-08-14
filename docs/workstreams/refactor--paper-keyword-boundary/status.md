# 论文关键词边界重构任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 1. 任务信息

| 项目 | 内容 |
| --- | --- |
| 目标 | 让论文关键词标签页与评论/AI 入口共享同一个 `PaperKeywordController`，消除 `PaperReaderView` 对关键词仓储和 freshness 规则的直接调用。 |
| 非目标 | 不改变关键词生成、缓存 schema、评论面板、ChatPaper 上下文或视觉交互；不处理其他报告问题；不合入 `main`，不进行人工桌面验收。 |
| 分支 | `refactor/paper-keyword-boundary` |
| worktree | `C:\Users\Fantasy\Desktop\Spark-worktrees\agent-9` |
| 基线 | `e742018c02fd6bfde63e8685f2798e5508a511aa`（上一批 `refactor/theme-controller-boundary` 最终审查提交） |
| 负责人 | Fantasy（编排）；Codex（执行） |
| 当前阶段 | `/review` 已完成；下一步基于最终审查提交创建新的串行 worktree |

## 2. 问题与边界

`PaperReaderCard` 已持有负责缓存加载、freshness 判断、生成和持久化的 `PaperKeywordController`，但 `PaperReaderView` 在打开评论或 AI 面板时又直接调用 `PaperKeywordRepository.load()` 并重复 freshness 判断，形成两套读取路径和展示层应用逻辑。本批复用卡片已有控制器，删除页面直读路径。

保持不变：

- 关键词缓存记录、fingerprint、prompt version 和 freshness 规则不变。
- 关键词标签页仍只在首次激活时加载一次。
- 缓存失败仍以空关键词打开讨论，并显示“无法读取已生成的关键词，已使用空关键词继续”。
- 缓存失败只由 `PaperKeywordController` 记录一次 `paperKeywordsLoad` 诊断。

## 3. 验收标准

1. `paper_reader_view.dart` 不调用关键词仓储 `load()`，不判断 `isPaperKeywordRecordFresh()`。
2. 关键词标签页与评论/AI 入口使用同一个 `PaperKeywordController` 状态；任一入口先初始化后，另一入口不重复加载缓存。
3. 新鲜缓存关键词能够原样传入讨论构建器；失效缓存仍由应用层过滤。
4. 缓存读取失败仍显示原反馈、以空关键词打开讨论，并且只记录一次 `paperKeywordsLoad`。
5. 现有标签页按需初始化、关键词生成和持久化行为保持通过。
6. 定向测试、`flutter analyze`、格式门禁和 `/test` 全量门禁全部通过。

## 4. 写入范围

### 独占路径

- `lib/src/features/papers/application/paper_keyword_controller.dart`
- `lib/src/core/diagnostics/runtime_diagnostics.dart`
- `lib/src/features/papers/presentation/widgets/paper_reader_card.dart`
- `lib/src/features/papers/presentation/widgets/paper_reader_view.dart`
- `test/paper_reader_view_test.dart`
- `test/architecture_boundaries_test.dart`
- 本台账

### 共享路径

- 无；本批串行基于上一批最终审查提交创建。

## 5. 实施计划

1. 增加共享缓存、失败回退和源码边界回归测试。
2. 由 `PaperReaderCard` 在调用评论/AI 回调前初始化已有关键词控制器，并将控制器关键词传给 `PaperReaderView`。
3. 删除 `PaperReaderView` 的仓储读取、freshness 判断和重复诊断；由控制器暴露明确的缓存加载失败状态。
4. 运行定向测试、analyze 和格式检查，形成原子实现提交。
5. 执行 `/test` 全量门禁和 `/review` 只读审查，记录最终串行基线。

## 6. 当前进度

- 已完成：核对报告、项目规范、上一批台账、相关实现和测试；确认问题成立。
- 已完成：评论、AI 入口与关键词标签页已复用 `PaperReaderCard` 持有的同一 `PaperKeywordController`；`PaperReaderView` 不再读取仓储或判断 freshness。
- 已完成：控制器并发初始化复用单次 Future，缓存失败只记录一次 `paperKeywordsLoad`，页面保留原反馈并以空关键词继续。
- 已完成：共享缓存、反向入口顺序、并发初始化、失败回退和源码边界回归测试已通过定向验证。
- 已完成：`/develop` 原子实现提交 `64df7fe` 已创建。
- 已完成：`/test` 格式、静态分析和 539 项全量测试全部通过。
- 已完成：`/review` 对照规格、8 个变更文件、结构清单和阻断条件完成只读审查，未发现阻断项、缺陷或建议。
- 正在进行：形成最终审查提交。
- 下一步：基于最终审查提交创建新 worktree，继续处理报告中的剩余有效问题。
- 阻塞项：无。

## 7. 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 保留 `PaperKeywordController` 在 `PaperReaderCard` 中的现有所有权，通过窄回调向上层传递已初始化关键词。 | 控制器本来就服务关键词标签页；复用同一实例可消除重复状态，又不扩大页面生命周期重构范围。 | 评论与 AI 入口改为接收关键词列表，缓存读取和 freshness 规则只保留在应用层。 |
| 2026-08-13 | 缓存失败诊断统一使用 `paperKeywordsLoad`。 | 失败由控制器捕获和记录；页面不应再用第二个展示层 operation 重复上报。 | 删除 `paperReaderKeywordsLoad` 的本次调用点，测试契约同步更新。 |

## 8. 验证记录

| 时间 | 阶段 | 命令或检查 | 结果 |
| --- | --- | --- | --- |
| 2026-08-13 20:33 | `/develop` | `flutter test test\paper_keyword_test.dart test\paper_reader_view_test.dart test\ui_preview_test.dart test\architecture_boundaries_test.dart` | 通过，共 53 项；关键词标签页和讨论入口无论先后均只读取一次缓存，新鲜缓存原样进入讨论，失败以空关键词继续。 |
| 2026-08-13 20:33 | `/develop` | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 20:33 | `/develop` | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 110 个变更相关 Dart 文件。 |
| 2026-08-13 20:33 | `/develop` | `git diff --check` 与源码搜索 | 通过；`paper_reader_view.dart` 无仓储 `load()`、freshness 判断或展示层关键词加载诊断。 |
| 2026-08-13 20:36 | `/test` | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 110 个变更相关 Dart 文件。 |
| 2026-08-13 20:36 | `/test` | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 20:36 | `/test` | `flutter test` | 通过，共 539 项测试；无失败、错误或超时。 |

## 9. 审查与交付

- 审查范围：`e742018c02fd6bfde63e8685f2798e5508a511aa..8b3868256fa2f8aaf860ffd1adddd9fc871794a1`，8 个文件，新增 342 行、删除 83 行；其中代码与测试 7 个文件，另有本任务台账。
- 规格核对：6 项验收标准全部满足；评论、AI 和关键词标签页共享同一控制器，freshness 只在应用层判断，失败反馈与单次诊断契约保持明确。
- 结构核对：逐项检查提交前结构清单和 10 条阻断条件；未触发 Widget 基础设施直连、Controller 创建具体仓储、领域层外部依赖、公共模块反向依赖、循环依赖、多职数据类型扩散、业务 utils、深层继承、超大页面新增独立流程或只能依赖完整 UI 验证等问题。
- 异步核对：并发初始化复用同一 Future；控制器替换、页面失活或销毁后，迟到加载不会打开错误论文的讨论面板。
- 阻断项：无。
- 缺陷：无。
- 建议：无。
- 审查结论：通过；不执行 `/finish`，不合入 `main`，最终审查提交作为下一批 worktree 基线。
- 兼容性：不修改持久化 schema、领域接口和远程契约。
- 风险：控制器异步初始化期间论文或依赖切换；通过捕获控制器实例并核对 identity 避免迟到回调打开错误论文。
- 回滚：按原子提交回滚，不触碰 `main`。
- 合并与归档：按用户要求不执行 `/finish`、不合入 `main`、不清理 worktree；最终审查提交作为下一批基线。

## 10. 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `64df7fe` | `重构（论文）：统一关键词缓存状态源` | `/develop` | 53 项定向测试、analyze、110 文件格式门禁通过；页面不再直读关键词仓储。 |
