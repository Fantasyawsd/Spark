# 任务台账

## 基本信息

- 任务：`ui-components-2026`（界面焕新 P2 · 组件现代化）
- 关联发布或里程碑：无（界面焕新系列第三阶段）
- 分支：`feature/ui-components-2026`（基于 `feature/ui-tokens-v2` 的叠加分支）
- Worktree：`../agent-2`
- 基线提交：`bad410e`（feature/ui-tokens-v2 tip）
- 负责人：编排者（人类）+ Claude Code Agent
- 状态：开发中
- 最近更新：2026-08-21 17:40

## 目标

按《界面焕新提案》完成 C1–C11 组件现代化（C12 归入 P3）：

1. C1 真玻璃底部导航栏；C2 网格卡微交互 + 徽标差异化；C3 阅读卡操作栏毛玻璃；
   C4 AI 解读渐变光晕胶囊；C5 触控目标 44px 专项；C6 气泡方向性圆角 + 三点脉冲；
   C7 思考面板扫光；C8 会话卡分层 + 欢迎页建议 chips；C9 设置分组卡 + 彩底图标；
   C10 搜索框胶囊化 + 统一空状态组件；C11 全屏阅读器字号档位 + 阅读进度条
   （页面转场已在 P1 完成）。

## 非目标

- 不做品牌个性项（衬线字体、启动屏、点赞弹跳、主题切换动画 → P3）。
- 不改业务逻辑与数据契约。

## 验收标准

- [x] 底部导航真实磨砂（alpha 0.80/0.68、sigma 24、高光描边、品牌粉选中态）。
- [x] 网格卡按压缩放 0.97 + Trending 琥珀火焰 / 为你推荐品牌粉徽标 + Wrap 布局。
- [x] 操作栏毛玻璃化（BackdropFilter blur20 + floatingShadow）。
- [x] AI 解读按钮渐变胶囊 + glow、38 高、padded 热区。
- [x] 全应用触控点 ≥44px 热区（CherryIconButton/TabBar/SegmentedControl 默认达标，
      论文与 Chat 各 shrinkWrap 点位修复）。
- [x] 用户气泡方向性圆角（bubbleTail=6）；typing indicator 三点脉冲（key: ai-typing-indicator）。
- [x] 思考面板 ShaderMask 扫光 + disableAnimations 定格。
- [x] 会话卡 hairline+微阴影+按压缩放；欢迎页 4 个建议 chips 接线 onPrompt 回填 composer。
- [x] 设置列表三组卡 + 30px 彩底图标容器。
- [x] 搜索框 radiusField；三处空状态统一为 SparkEmptyState。
- [x] 阅读器字号档位（15/17/19）+ 底部阅读进度条。
- [x] `flutter analyze` 无问题、`flutter test` 612 项全绿、格式门禁通过。

## 写入范围

### 独占路径

- core：cherry_primitives / spark_tab_bar / spark_segmented_control / spark_empty_state(新增) /
  spark_design_tokens(bubbleTail)
- papers：paper_grid_card / topic_chip / paper_reader_card / paper_reader_content /
  paper_metadata / paper_pdf_button / paper_translation_content / paper_comments_content /
  paper_tab_body / paper_full_reader_page
- chat：ai_chat_home_screen / paper_ai_chat_screen / paper_ai_content /
  paper_ai_message_bubbles / paper_ai_reasoning_panel / paper_ai_message_actions /
  paper_ai_composer_parts / paper_ai_composer_sheets
- shell/profile/search：spark_bottom_nav / profile_settings_section / paper_search_screen /
  paper_shelf_list_screen / favorite_collection_section
- 测试适配：widget_test / local_data_sheet_test / chat_background_completion_test /
  paper_interaction_flow_test

### 共享路径

- 无

## 依赖关系

- 上游任务：fix/ui-correctness（P0）、feature/ui-tokens-v2（P1，未合 main，本分支叠加其上）
- 外部接口或数据源：无

## 实施计划

1. 共享组件层（token/通用组件）→ verify: analyze
2. papers 模块改造 → verify: analyze + 定向测试
3. chat 模块改造（并行 agent）→ verify: analyze + 定向测试
4. shell/profile/search 改造（并行 agent）→ verify: analyze + 定向测试
5. 全量测试回归 + 失败修复 → verify: 612 全绿

## 当前进度

- 已完成：全部实施与验证（analyze 无问题、test 612 全绿、format 通过）
- 正在进行：提交
- 下一步：等待编排者验收；合并顺序须先 P1 后本分支
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-21 | 操作栏毛玻璃保留但放弃「内容穿透」（维持 inset+96 避让） | 实测穿透后「展开全文」按钮先后被毛玻璃操作栏与 AI 解读悬浮钮遮挡（hit-test miss），空间冲突不可调和 | 玻璃视觉与阴影保留；穿透列为后续方向 |
| 2026-08-21 | typing indicator 换三点脉冲并加 `ai-typing-indicator` key | 测试断言锁定 CircularProgressIndicator（旧实现），新实现以 key 暴露测试锚点 | paper_interaction_flow_test 断言同步更新 |
| 2026-08-21 | 设置分组卡化后更新三个测试的滚动策略 | 页面变高使版本行/本地数据行落在视口底缘（被悬浮底栏遮挡或未构建）；scrollUntilVisible 后补向上 drag / 版本行补 scrollUntilVisible | widget_test / local_data_sheet_test / chat_background_completion_test |
| 2026-08-21 | SliverAppBar.large 大标题跳过 | 会改变滚动偏移恢复语义（initialScrollOffset 基准变化），风险大于收益 | 记录为后续项 |
| 2026-08-21 | 流式输出 ▍ 光标跳过 | 需侵入 SparkMarkdown 渲染管线，超出本阶段边界 | 记录为后续项 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| flutter analyze | 无问题 | 2026-08-21 |
| flutter test | 612 项全部通过 | 2026-08-21 |
| tool/verify_changed_dart_format.ps1 | 通过 | 2026-08-21 |
| 双端发布版构建 | 统一在界面焕新系列全部合入后于 main 执行一次 | - |

## 审查结论

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

（待合并前补齐）

### 实际变更

- 界面与交互：C1-C11 组件现代化（详见验收标准）
- 测试与工具：四个测试文件的布局适配与断言更新

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：TopicChip 新增 icon/tonal 参数；SparkTabBar/SparkSegmentedControl 默认高度 38→44；CherryIconButton 命中区外扩至 44（视觉尺寸不变）
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：玻璃效果在低端 Android 设备的 GPU 开销（BackdropFilter ×2：底栏+操作栏）；TextTheme/P1 叠加变更需一并验收
- 回滚方式：revert 本分支合并提交（须连同 P1 一起回滚或保持 P1）

### 文档更新建议

- 开发计划不受影响（视觉升级）

### 未完成与后续工作

- 操作栏内容穿透（需重排展开全文/AI 解读入口）
- SliverAppBar.large 大标题（需解决滚动偏移恢复语义）
- 流式 ▍ 光标（需 SparkMarkdown 管线支持）
- C12 点赞弹跳/计数滚动（P3）

## 合并归档（合并后在 main 补齐）

- 最终状态：
- 合入分支：
- 最终集成提交：
- 合并时间：
- main 集成验证：
- 开发计划更新：
- 最终后续项：
