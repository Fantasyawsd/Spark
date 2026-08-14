# Phase 4.7 个性化开关与偏好展示任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

Phase 4 客户端收口（UI 任务，实现：workflow + kimi-coding/k3-256k）：

1. 隐私设置新增「个性化推荐」区：开关绑定行为采集同意（默认开、关闭即停采）；「清除行为数据」入口（确认对话框）同时清除行为事件与画像。
2. 隐私删除边界收口：behavior 事件/同意/画像三份本地文件纳入「本地数据」清理与占用统计（JsonLocalDataRepository）。
3. 推荐偏好来源展示：Paper 增补 personalizationScore，mapper 从 Paper API 提取；信息流卡片在偏好分 > 0 时渲染「为你推荐」chip（production arXiv 直连无该字段，零展示变化）。
4. Widget 测试：开关切换、清除确认流程、卡片 chip 有/无渲染。

## 非目标

- 不改动服务端（4.1-4.6 已完成）。
- 不展示具体偏好主题列表（仅开关与清除）。

## 分支与基线

- 分支：`feature/phase4-personalization-ui`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`2dd574e`
- 负责人：Fantasy（编排者，目标迭代授权）；实现：workflow + kimi-coding/k3-256k

## 验收标准

- [x] 开关与同意存储双向同步
- [x] 清除行为数据（事件 + 画像）有确认与反馈
- [x] behavior 三文件纳入本地数据统计与清理
- [x] 「为你推荐」chip 有/无信号渲染正确
- [x] `flutter analyze` 无问题、`flutter test` 全量通过（608 项）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| workflow 实现 agent（kimi-coding/k3-256k） | 控制器、隐私 UI、清理收口、为你推荐 chip + 7 项测试；编排等待超时但实现完整 | 2026-08-14 |
| workflow 审查 agent（kimi-coding/k3-256k） | 编排超时未产出；编排者直接只读审查并修复 3 处（冗余 import、控制器初始化时序断言、profile 滚动测试固定偏移） | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test`（全量） | 608 项通过 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（我的）：个性化开关与偏好展示` | 实现（workflow + 编排者审查修复） | analyze 无问题、608 项通过 |

## 审查结论

编排者只读审查（workflow 编排超时后接手）：分层合规（profile 经公开入口依赖 behavior domain 端口与控制器）、开关与 consent 双向同步、清除覆盖事件与画像、behavior 三文件进入本地数据统计与清理、chip 无信号零展示变化、dto 非法字段容错。修复 3 处测试脆弱点后全量通过。无阻断项。
