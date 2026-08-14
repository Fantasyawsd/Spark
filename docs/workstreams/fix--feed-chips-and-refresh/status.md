# 修复：滑动信息流徽标缺失与滑到底不刷新任务台账

> 状态：已合并
> 最近更新：2026-08-14

## 目标

修复人工验收发现的问题（最终范围经用户验收确认）：

1. ~~徽标不显示~~ **已按用户决定暂缓（chips 先算了）**：滑动信息流 Trending/为你推荐 chip 及其 `recommendationPool` 数据链路已整体移除，代码回到修复前状态。
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

- [x] 推荐频道滑到底触发强制刷新（新 batch 追加）
- [x] 非推荐频道行为不变
- [x] 单栏切双栏时网格停在当前论文所在区域
- [x] chips 改动已按用户决定整体移除（暂缓）
- [x] `flutter analyze` 无问题、`flutter test` 全量通过

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test`（全量） | 611 通过、0 失败 | 2026-08-14 |
| `tool\verify_changed_dart_format.ps1` | 通过 | 2026-08-14 |
| 人工验收 | 滑到底刷新、单栏切双栏定位通过；chips 由用户决定暂缓并移除 | 2026-08-14 |
| main 集成验证：`flutter build windows --release` | 成功 | 2026-08-14 |
| main 集成验证：`flutter build apk --profile`（development flavor，无签名配置） | 成功 | 2026-08-14 |

### 发布产物（main 集成构建）

| 产物 | 路径 | 大小 | SHA-256 |
| --- | --- | --- | --- |
| Windows EXE | `build\windows\x64\runner\Release\spark.exe` | 101,888 B | `FABCF368E017AE6A69BD6151E5B9F3D5ACB47EE2296B4BD387D99486A52C741F` |
| Development APK（profile） | `build\app\outputs\flutter-apk\app-development-profile.apk` | 91,348,965 B | `4249AC92BDB6AD35002183194F9DEAFBAB15A04474B9FEE9FD6770937E5B38C1` |

> APK 为 profile 构建（AOT，等同发布性能）：`android/key.properties` 不存在，release 签名门控不满足。

## 实施要点

- `loadMoreCatalog`：推荐频道无 cursor/offset 时转 `refreshCatalog(forceRefresh: true)`（新 seed 新 batch，服务端排除已读与当前列表）；非推荐频道保持原样。
- `PapersScreen`：网格挂持久 `ScrollController`，单栏→双栏切换时锚定 `currentPaperIndex`（估算行偏移跳转 + 锚点 key `ensureVisible` 逐帧修正，兼容瀑布流可变高度与懒加载）。
- 新增测试：推荐频道滑到底刷新、非推荐频道静默、单栏切双栏网格定位；grid 分页测试切到 latest 频道（offset 分页语义），推荐频道无游标语义由控制器测试覆盖。
- chips 相关实现与测试已整体移除（滑动卡片 chip 区、presenter 池标记兜底、`recommendationPool` 字段与 DTO 映射）。

## 检查点与提交

- `34c785f` 修复（论文信息流）：滑动卡片渲染 Trending/为你推荐 chip 并支持滑到底刷新
- `46dcb58` 修复（论文信息流）：单栏切双栏时网格停在当前论文所在区域
- `b32ec4e` 重构（论文信息流）：按验收决定暂缓 chips 功能并移除相关实现

## 合并

- 方式：fast-forward 合入 `main`（无冲突，无 PR；日常开发由编排者确认后直接合并）
- 集成 SHA：`b32ec4e`
- 合并时间：2026-08-14
- 集成验证：分支通过全部门禁（analyze / 611 测试 / 格式检查）；合入后在 main 复跑 `flutter analyze` + `flutter test` 全量并通过，双目标发布构建产物见「发布产物」。
- 回滚：回退 `b32ec4e` 即可（ff 无中间状态）。
