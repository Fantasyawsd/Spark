# 未完成功能检查报告

> 状态：已完成（2026-08-14）
> 基线：main @ eb232c6
> 检查方式：对照 `docs/development.md` 第 3 节开发任务清单，逐项核对 `lib/`、`server/` 代码与测试证据；运行 `flutter analyze` 与全量 `flutter test` 确认代码库健康。

## 结论摘要

- 开发计划中标记为「暂缓」「待开始」「进行中」的功能与代码现状基本一致，共 8 项未完成。
- 发现 1 处文档与代码不一致：§3.2 任务 2「修复论文聊天『读取全文』异常反馈」已实际完成并有测试证据，但 `development.md` 仍标记「暂缓」。
- 发现 1 处文档描述偏差：§3.3 任务 3「用户侧迁移失败恢复」底层隔离/恢复机制已具备，但「显式恢复、损坏隔离结果和用户反馈」未见实现，维持「进行中」。
- 服务端 Phase 3–5（热点、个性化、高级推荐）无代码，符合「后续阶段」标记。
- 代码库健康：`flutter analyze` 无问题，`flutter test` 582 项全部通过。

## 未完成功能清单

### §3.1 客户端论文阅读

| # | 任务 | 开发计划状态 | 代码证据 | 核验结论 |
| --- | --- | --- | --- | --- |
| 1 | 六问结构化 AI 解读与缓存 | 暂缓 | `PaperReaderAiInterpretationContent` 仅为空状态「围绕当前论文提问」并引导打开 ChatPaper；无六问生成、版本化缓存、失败恢复代码 | 确认未完成，与文档一致 |
| 2 | AI 解读进入论文 ChatPaper 默认上下文 | 暂缓 | `PaperChatContextLoader` 只注入元数据 + 关键词 + 可选 PDF 分块，无六问注入；依赖任务 1 | 确认未完成，与文档一致 |
| 3 | 相关论文语义检索 | 待开始 | `PaperRelatedPapers` 空状态文案「相关论文推荐将在后续版本提供」；无检索实现 | 确认未完成，与文档一致 |

### §3.2 ChatPaper

| # | 任务 | 开发计划状态 | 代码证据 | 核验结论 |
| --- | --- | --- | --- | --- |
| 2 | 修复论文聊天「读取全文」异常反馈 | 暂缓（文档） | `PaperAiChatAppBar._toggleFullText` 已实现 try/catch/finally 复位 loading + SnackBar 错误提示（「无法读取论文全文，请稍后重试。」「全文上下文与当前会话不匹配，请重试。」）；`paper_ai_chat_app_bar_test.dart`、`paper_ai_mobile_chat_ui_test.dart`、`paper_pdf_test.dart` 覆盖下载失败、解析失败、上下文不匹配、无 PDF、超时 | **实际已完成，文档未同步更新** |
| 3 | 主聊天侧边追问（side chat） | 待开始 | `lib/` 中无 SideChat/side chat 任何实现 | 确认未完成，与文档一致 |

> 注：任务 1「离开聊天界面后继续完成回复」在开发计划中为已完成，代码与测试（`chat_background_completion_test.dart` 等）确认无遗漏，不列入未完成清单。

### §3.3 我的

| # | 任务 | 开发计划状态 | 代码证据 | 核验结论 |
| --- | --- | --- | --- | --- |
| 1 | 收藏分组排序与批量移动 | 待开始 | `PaperInteractionController` 仅有 create/rename/delete；数据层 `favoriteGroups` 为 List 保留插入顺序，但无排序或批量移动 API/UI | 确认未完成，与文档一致 |
| 2 | 个人研究数据导出 / 导入 / 备份恢复 | 待开始 | `local_data` 模块仅有占用统计与分类清理；无导出/导入/备份功能 | 确认未完成，与文档一致 |
| 3 | 用户侧迁移失败恢复 | 进行中 | 底层已具备：`VersionedLocalJsonStore` 损坏隔离（`.corrupt.` 文件 + `LocalDataCorruptionException`）、`LocalJsonStore` 中断写入恢复（`.previous` 文件）、占用统计与分类清理覆盖恢复产物；但未见「显式恢复入口」「损坏隔离结果展示」或专门用户反馈 UI | 维持进行中；底层完成、用户侧未完成 |

### 服务端数据主线

| 阶段 | 开发计划状态 | 代码证据 | 核验结论 |
| --- | --- | --- | --- |
| Phase 3：热点能力增强（Web Heat、LLM Trend Scout、Trend Boost） | 后续阶段 | `server/` 中无 web_heat/trend_boost 等实现 | 确认未实现，符合「后续阶段」 |
| Phase 4：个性化推荐 | 后续阶段 | `server/` 中无 personalized/Two-Tower 等实现 | 确认未实现，符合「后续阶段」 |
| Phase 5：高级推荐系统 | 后续阶段 | 同上 | 确认未实现，符合「后续阶段」 |

### 其他确认项（不属于未完成）

- 社区/私信：`experimentalCommunity` 默认关闭，production 强制关闭，未接入生产导航——符合文档边界，非缺陷。
- 隐藏未接线同步入口：`a07ba6e` 已移除 `paper_sync_service.dart` 与 `paper_sync_ports.dart` 公共导出并有静态门禁。
- 主题/会议管理页：`PaperChannelManagerSheet` 存在（主题/会议 tab），会议频道由 `experimentalConferenceChannels` 门控。
- DeepSeek Key：安全存储 + 掩码展示 + 单独删除，未随业务数据重置删除。
- 代码中无 TODO/FIXME/HACK/未实现占位标记残留。

## 建议后续动作

1. 更新 `docs/development.md`：§3.2 任务 2 状态改为「已完成」，补充修复证据与测试覆盖（下载失败、解析失败、上下文不匹配、无 PDF、超时）。
2. 若启动 §3.3 任务 3（用户侧迁移失败恢复），范围应聚焦：显式恢复入口、损坏隔离结果展示、用户反馈（现有底层机制可复用）。
3. 其余待开始/暂缓任务按开发计划既有优先级排期，无需本次改动。