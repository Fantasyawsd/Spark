# Phase 3.6 热点原因 Client 展示任务台账

> 状态：已合并
> 最近更新：2026-08-14

## 目标

把服务端 web_heat 信号展示到客户端信息流：

1. 领域 `Paper` 增补 `webTrendReason`（String?）与 `webTrendTopics`（List<String>）；`paper_api_mapper` 从 `signals.web_heat` 提取 `trend_reason`/`trend_topics`。
2. 信息流卡片（`paper_grid_card.dart`）在徽标行渲染「Trending · <原因>」chip；无信号不显示（production arXiv 直连优雅降级）。
3. Widget 测试：有/无 webTrendReason 的渲染断言。
4. 验证：`flutter analyze`、`flutter test`（全量）、格式检查；合并后双目标构建（development APK profile + Windows release）。

## 非目标

- 不改动推荐服务端字段与权重（3.7 统一）。
- 不在论文详情页展示热点信息（仅信息流卡片）。

## 分支与基线

- 分支：`feature/phase3-client-trend-display`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`a1de85c`
- 负责人：Fantasy（编排者，目标迭代授权）；实现：workflow 子代理

## 决策记录

- 2026-08-14：目标指定 UI 任务用 kimi k3-256K，经 workflow 探测（kimi k3-256K / kimi-k3-256K）该模型在当前环境不可用；回退默认模型走 workflow 实现，本台账保留证据。

## 验收标准

- [x] Paper 模型与 mapper 提取 web_heat 信号
- [x] 卡片 Trending chip 有/无信号行为正确
- [x] Widget 测试覆盖两种渲染
- [x] `flutter analyze` 无问题、`flutter test` 全量通过（588 项）
- [x] 合并后 development APK（profile）与 Windows release 构建成功并记录产物（/finish 执行）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| workflow 实现 agent | 4 个 Dart 文件改动 + 3 条卡片 Widget 测试 | 2026-08-14 |
| workflow 审查 agent | 通过，非阻断观察项：mapper 提取缺直接单测（已补） | 2026-08-14 |
| 补 mapper 单测（3 条） | 通过 | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test`（全量） | 588 项通过 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（论文）：信息流卡片展示热点原因` | 实现（workflow） | analyze 无问题、588 项通过 |

## 合并归档

- 合并方式：本地快进合并（`main` `a1de85c..d1dcfd1`）
- 最终集成提交：`d1dcfd1`
- 合并时间：2026-08-14
- 集成验证（/finish 双目标构建）：
  - Windows release：`build/windows/x64/runner/Release/spark.exe`，101,888 bytes，SHA-256 `CDFCDE6D1129AA3B01FAF6DDCBC8FEAAB9D92B647A6B7BD00B9C712E579BA28A`
  - Android development profile：`build/app/outputs/flutter-apk/app-development-profile.apk`，119,638,924 bytes，SHA-256 `A053943CAFEE9D13E17A1EB82973A20F4BBF389B037D43A60EAF862FCBE2F924`；无 `android/key.properties`，按规范使用 profile
  - Gradle daemon：`--stop` 后 `--status` 显示 STOPPED，无运行中残留
- 真实后续项：3.7 Web Heat 接入 TrendScore 权重版本（最后一个 Phase 3 子任务）。

## 审查结论

workflow 审查 agent 结论：通过。分层正确（领域字段 → mapper 提取 → presenter 文案 → widget 条件渲染）；无 web_heat 时零展示变化；mapper 对缺失/非字符串/空值健壮。非阻断观察项（mapper 提取缺直接单测）已由编排者补齐 3 条单测。
