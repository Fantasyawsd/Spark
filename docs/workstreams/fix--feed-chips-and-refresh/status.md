# 修复：滑动信息流徽标缺失与滑到底不刷新任务台账

> 状态：开发中
> 最近更新：2026-08-14

## 目标

修复人工验收发现的两个问题：

1. 徽标不显示：Trending/为你推荐 chip 只渲染在网格卡片，滑动信息流（PaperReaderView 的 Abstract 页）未渲染；且 Trending chip 依赖 web_heat 原因字段，真实库无该信号时永不显示。修复：chip 上 Abstract 页标签区；Trending 在无原因但有 trending 池标记时兜底显示「Trending」；为你推荐双保险（分数或 personalized 池标记）。
2. 滑到底不刷新：推荐频道无分页游标时 loadMoreCatalog 直接返回。修复：recommended 频道滑到底触发强制刷新（新 seed 新 batch，排除当前列表与已读——该排除语义已由 _readPaperIdsForRequest 实现）。
3. 单栏切双栏回到顶部：网格使用全新的内部 ScrollController，每次切换都从 offset 0 开始。修复：网格挂持久 ScrollController，切换时锚定 currentPaperIndex（按平均行高估算跳转 + 锚点 key ensureVisible 逐帧精确对齐），双栏停在当前论文所在区域。

## 非目标

- 不改服务端。
- 不改变网格卡片既有 chip 渲染。

## 分支与基线

- 分支：`fix/feed-chips-and-refresh`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`07330ff`
- 负责人：Fantasy（编排者）；执行：DeepSeek Agent

## 验收标准

- [x] Abstract 页标签区渲染 Trending/为你推荐 chip
- [x] trending 池论文无原因时兜底显示「Trending」
- [x] 推荐频道滑到底触发强制刷新（新 batch 追加）
- [x] 非推荐频道行为不变
- [x] 单栏切双栏时网格停在当前论文所在区域
- [x] `flutter analyze` 无问题、`flutter test` 全量通过

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test`（全量） | 613 通过、0 失败 | 2026-08-14 |
| `tool\verify_changed_dart_format.ps1` | 11 个文件通过 | 2026-08-14 |
| 人工验收（chip + 滑到底刷新 + 单栏切双栏定位） | 待用户 `flutter run -d windows` 验证 | — |

## 实施要点

- `Paper` 新增 `recommendationPool` 字段（DTO `pool` 映射，仅推荐频道返回）。
- `trendLabel`：有 `webTrendReason` 时「Trending · 原因」，否则 trending 池兜底「Trending」。
- `personalizationLabel`：分数 > 0 或 personalized 池标记时「为你推荐」。
- `PaperReaderCard` 标题下方渲染 chip Wrap（TopicChip compact）。
- `loadMoreCatalog`：推荐频道无 cursor/offset 时转 `refreshCatalog(forceRefresh: true)`（新 seed 新 batch，服务端排除已读与当前列表）；非推荐频道保持原样。
- `PapersScreen`：网格挂持久 `ScrollController`，单栏→双栏切换时锚定 `currentPaperIndex`（估算行偏移跳转 + 锚点 key `ensureVisible` 逐帧修正，兼容瀑布流可变高度与懒加载）。
- 新增测试：chip 渲染 6 组断言、推荐频道滑到底刷新、非推荐频道静默、`pool`→`recommendationPool` 映射、单栏切双栏网格定位；grid 分页测试切到 latest 频道（offset 分页语义），推荐频道无游标语义由控制器测试覆盖。

## 检查点与提交

- 待提交：客户端实现 + 测试（单一逻辑提交）。
- 待合并：编排者确认后合入 `main` 并归档。
